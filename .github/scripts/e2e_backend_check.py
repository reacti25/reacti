"""Proves the device-test backend works end to end, the way the app uses it.

Logs in both smoke accounts, subscribes smoke-a to its private live channel
on Reverb (auth through the API like the app), has smoke-b send a message,
and waits for it to arrive over the websocket. Exits non-zero on any step.

Needs the backend from e2e_backend.sh plus REVERB_APP_KEY and
STAGING_SEED_PASSWORD in the environment, and `pip install websockets`.

Usage: python .github/scripts/e2e_backend_check.py
"""

import asyncio
import json
import os
import urllib.request

import websockets

API = "http://127.0.0.1:8000/api"
WS = f"ws://127.0.0.1:8080/app/{os.environ['REVERB_APP_KEY']}?protocol=7"
TIMEOUT = 10


def post(path: str, body: dict, token: str | None = None) -> dict:
    """POSTs JSON to the API and returns the decoded reply; raises on non-2xx."""
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(API + path, json.dumps(body).encode(), headers)
    with urllib.request.urlopen(request, timeout=TIMEOUT) as reply:
        return json.load(reply)


def login(email: str) -> dict:
    """Logs a seeded account in; returns its user data including `id` and `token`."""
    return post("/login", {"email": email, "password": os.environ["STAGING_SEED_PASSWORD"]})["data"]


async def wait_for_event(ws, name: str) -> dict:
    """Reads websocket frames until one is the named event; times out after TIMEOUT seconds."""
    async with asyncio.timeout(TIMEOUT):
        while True:
            frame = json.loads(await ws.recv())
            if frame.get("event") == name:
                return frame


async def subscribe(ws, user: dict, channel: str) -> None:
    """Subscribes to a private channel, signed by the API's broadcasting/auth like the app does."""
    hello = await wait_for_event(ws, "pusher:connection_established")
    socket_id = json.loads(hello["data"])["socket_id"]
    auth = post("/broadcasting/auth", {"socket_id": socket_id, "channel_name": channel}, user["token"])["auth"]
    await ws.send(json.dumps({"event": "pusher:subscribe", "data": {"auth": auth, "channel": channel}}))
    await wait_for_event(ws, "pusher_internal:subscription_succeeded")


async def main() -> None:
    """Runs the check: smoke-b's message must reach smoke-a live."""
    a, b = login("smoke-a@reacti.test"), login("smoke-b@reacti.test")
    text = "e2e check"
    async with websockets.connect(WS) as ws:
        await subscribe(ws, a, f"private-chat-receiver.{a['id']}")
        post(f"/auth/chat/send/{a['id']}", {"text": text}, b["token"])
        event = await wait_for_event(ws, "App\\Events\\MessageSendEvent")
    received = json.loads(event["data"])["chat"]["text"]
    assert received == text, f"expected {text!r}, got {received!r}"
    print("Test server check passed: login, live channel auth, message delivered live.")


if __name__ == "__main__":
    asyncio.run(main())
