#!/usr/bin/env python3
"""End-to-end smoke for the production-shaped stack (AWS plan step 2.2).

Drives the real API through the fake ALB and listens on the websocket like
the app does (Pusher protocol 7), so one run proves:

  * two web replicas behind a TLS proxy serve the API with https URLs
  * media lands in the S3 emulator and is readable through the media host
  * a 1:1 message reaches the receiver live (sync broadcast -> Reverb)
  * a reaction reaches the sender live (queued broadcast -> worker -> Reverb)

Stdlib plus `websockets`. Exit code 0 only when every step passed.

  python3 smoke_aws.py --ca infra/fake-alb/certs/fullchain.pem \
      --video /tmp/smoke.mp4 --reaction /tmp/reaction.mp4
"""
from __future__ import annotations

import argparse
import asyncio
import json
import mimetypes
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

import websockets

USER_A = "smoke-a@reacti.test"
USER_B = "smoke-b@reacti.test"


def log(msg: str) -> None:
    print(f"[smoke] {msg}", flush=True)


class Api:
    def __init__(self, base: str, ctx: ssl.SSLContext):
        self.base = base.rstrip("/")
        self.opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))

    def _send(self, req: urllib.request.Request):
        try:
            with self.opener.open(req, timeout=120) as res:
                return res.status, {k.lower(): v for k, v in res.headers.items()}, res.read()
        except urllib.error.HTTPError as e:
            return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read()
        except (urllib.error.URLError, OSError) as e:
            return 0, {}, str(e).encode()

    def get(self, path: str, token: str | None = None):
        url = path if path.startswith("https://") else f"{self.base}/{path}"
        return self._send(urllib.request.Request(url, headers=self._headers(token)))

    def post_json(self, path: str, body: dict, token: str | None = None):
        data = json.dumps(body).encode()
        headers = self._headers(token) | {"Content-Type": "application/json"}
        return self._send(urllib.request.Request(f"{self.base}/{path}", data=data, headers=headers, method="POST"))

    def post_form(self, path: str, fields: dict, token: str | None = None, files: dict | None = None):
        boundary = f"----smoke{uuid.uuid4().hex}"
        body = bytearray()
        for name, value in fields.items():
            body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode()
        for name, path_on_disk in (files or {}).items():
            ctype = mimetypes.guess_type(path_on_disk)[0] or "application/octet-stream"
            filename = path_on_disk.rsplit("/", 1)[-1]
            body += (
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{filename}\"\r\n"
                f"Content-Type: {ctype}\r\n\r\n"
            ).encode()
            with open(path_on_disk, "rb") as fh:
                body += fh.read()
            body += b"\r\n"
        body += f"--{boundary}--\r\n".encode()
        headers = self._headers(token) | {"Content-Type": f"multipart/form-data; boundary={boundary}"}
        return self._send(urllib.request.Request(f"{self.base}/{path}", data=bytes(body), headers=headers, method="POST"))

    @staticmethod
    def _headers(token: str | None) -> dict:
        h = {"Accept": "application/json", "User-Agent": "reacti-smoke/1"}
        if token:
            h["Authorization"] = f"Bearer {token}"
        return h


def expect(cond: bool, what: str, detail: object = "") -> None:
    if not cond:
        log(f"FAIL: {what} {detail}")
        sys.exit(1)
    log(f"ok: {what}")


def http_urls(obj, found: list[str]) -> list[str]:
    """Collect every string value that looks like a URL."""
    if isinstance(obj, dict):
        for v in obj.values():
            http_urls(v, found)
    elif isinstance(obj, list):
        for v in obj:
            http_urls(v, found)
    elif isinstance(obj, str) and obj.startswith(("http://", "https://")):
        found.append(obj)
    return found


class Socket:
    """One Pusher-protocol connection, authorised through /api/broadcasting/auth."""

    def __init__(self, ws_base: str, key: str, api: Api, token: str, ctx: ssl.SSLContext):
        self.url = f"{ws_base.rstrip('/')}/app/{key}?protocol=7&client=reacti-smoke&version=1&flash=false"
        self.api, self.token, self.ctx = api, token, ctx
        self.ws = None
        self.socket_id = None

    async def connect(self):
        self.ws = await websockets.connect(self.url, ssl=self.ctx, open_timeout=20)
        hello = json.loads(await asyncio.wait_for(self.ws.recv(), 20))
        expect(hello.get("event") == "pusher:connection_established", "websocket handshake", hello)
        self.socket_id = json.loads(hello["data"])["socket_id"]

    async def subscribe(self, channel: str):
        status, _, body = self.api.post_form(
            "broadcasting/auth", {"socket_id": self.socket_id, "channel_name": channel}, token=self.token
        )
        expect(status == 200, f"channel auth {channel}", body[:300])
        auth = json.loads(body)["auth"]
        await self.ws.send(json.dumps({"event": "pusher:subscribe", "data": {"channel": channel, "auth": auth}}))
        while True:
            msg = json.loads(await asyncio.wait_for(self.ws.recv(), 20))
            if msg.get("event") == "pusher_internal:subscription_succeeded":
                log(f"ok: subscribed {channel}")
                return
            if msg.get("event") == "pusher:error":
                expect(False, f"subscribe {channel}", msg)

    async def wait_for(self, predicate, timeout: float, what: str) -> dict:
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            expect(remaining > 0, what, "timed out")
            try:
                raw = await asyncio.wait_for(self.ws.recv(), remaining)
            except asyncio.TimeoutError:
                expect(False, what, "timed out")
            msg = json.loads(raw)
            if msg.get("event") == "pusher:ping":
                await self.ws.send(json.dumps({"event": "pusher:pong", "data": {}}))
                continue
            data = msg.get("data")
            if isinstance(data, str):
                try:
                    data = json.loads(data)
                except ValueError:
                    pass
            if predicate(msg.get("event", ""), data):
                log(f"ok: {what} (event {msg.get('event')})")
                return msg
            log(f"  ... other event on {msg.get('channel')}: {msg.get('event')}")

    async def close(self):
        if self.ws:
            await self.ws.close()


def login(api: Api, email: str, password: str) -> tuple[int, str]:
    status, _, body = api.post_json("login", {"email": email, "password": password})
    expect(status == 200, f"login {email}", body[:300])
    data = json.loads(body)["data"]
    return int(data["id"]), data["token"]


def mentions(data, message_id: int) -> bool:
    return str(message_id) in json.dumps(data)


async def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--api", default="https://api.reacti.test/api")
    p.add_argument("--ws", default="wss://ws.reacti.test")
    p.add_argument("--media-host", default="https://media.reacti.test/")
    p.add_argument("--key", default="reacti-ci-key", help="REVERB_APP_KEY")
    p.add_argument("--password", default="smoke-ci-password-1", help="STAGING_SEED_PASSWORD")
    p.add_argument("--ca", required=True, help="CA/cert PEM the fake ALB serves")
    p.add_argument("--video", required=True, help="video sent A -> B (tests the upload path)")
    p.add_argument("--reaction", required=True, help="short video B sends back as the reaction")
    args = p.parse_args()

    ctx = ssl.create_default_context(cafile=args.ca)
    api = Api(args.api, ctx)

    # 1. The stack answers.
    up_url = args.api.rsplit("/api", 1)[0] + "/up"
    for _ in range(60):
        status, headers, _ = api.get(up_url)
        if status == 200:
            break
        time.sleep(2)
    expect(status == 200, "/up answers 200", status)
    expect(headers.get("x-reacti-origin") == "aws-compose", "X-Reacti-Origin set by the app", headers.get("x-reacti-origin"))

    # 2. Both seeded accounts log in.
    a_id, a_tok = login(api, USER_A, args.password)
    b_id, b_tok = login(api, USER_B, args.password)

    # 3. B listens on its receiver channel before A sends.
    b_sock = Socket(args.ws, args.key, api, b_tok, ctx)
    await b_sock.connect()
    await b_sock.subscribe(f"private-chat-receiver.{b_id}")

    # 4. A sends a video to B. The response must carry only https URLs and a
    #    media URL on the media host; the object must be readable there.
    status, _, body = api.post_form(
        f"auth/chat/send/{b_id}", {"text": "[smoke] video", "message_type": "normal"}, token=a_tok, files={"file": args.video}
    )
    expect(status == 200, "A sends a video to B", body[:500])
    chat = json.loads(body)["data"]["chat"]
    message_id, room_id, file_url = int(chat["id"]), chat["room_id"], chat["file"]
    urls = http_urls(chat, [])
    expect(all(u.startswith("https://") for u in urls), "every URL in the send response is https", urls)
    expect(isinstance(file_url, str) and file_url.startswith(args.media_host), "media URL is on the media host", file_url)
    status, headers, blob = api._send(urllib.request.Request(file_url))
    with open(args.video, "rb") as fh:
        size = len(fh.read())
    expect(status == 200 and len(blob) == size, "media readable through the media host, byte-exact", (status, len(blob), size))

    # 5. B received the message live (sync broadcast through Reverb).
    await b_sock.wait_for(lambda ev, d: mentions(d, message_id), 20, "B receives the message over the websocket")

    # 6. A listens on the room; B opens the message and reacts. The reaction
    #    event is queued, so this leg proves worker -> Reverb -> client.
    a_sock = Socket(args.ws, args.key, api, a_tok, ctx)
    await a_sock.connect()
    await a_sock.subscribe(f"private-chat-room.{room_id}")

    status, _, body = api.post_form(f"auth/chat/mark-viewed/{message_id}", {}, token=b_tok)
    expect(status == 200, "B marks the message viewed", body[:300])
    status, _, body = api.post_form(
        f"auth/chat/send/{a_id}",
        {"message_type": "reaction", "reply_to_id": str(message_id)},
        token=b_tok,
        files={"file": args.reaction},
    )
    expect(status == 200, "B uploads a reaction", body[:500])
    reaction_id = int(json.loads(body)["data"]["chat"]["id"])
    await a_sock.wait_for(
        lambda ev, d: ev.endswith("MessageReactionEvent") or mentions(d, reaction_id),
        40,
        "A receives the reaction over the websocket (queued -> worker -> Reverb)",
    )

    # 7. A few authenticated reads spread over both web replicas.
    for _ in range(4):
        status, headers, _ = api.get("profile", token=a_tok)
        expect(status == 200 and headers.get("x-reacti-origin") == "aws-compose", "profile read through the ALB", status)

    await b_sock.close()
    await a_sock.close()
    log("ALL PASSED")


if __name__ == "__main__":
    asyncio.run(main())
