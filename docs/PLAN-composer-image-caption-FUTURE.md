# Future feature — caption with image (NOT STARTED)

**Status:** parked / not started. Separate, isolated feature — do not bundle with
the composer attachment fix (`docs/PLAN-composer-attachment-ux-2026-06-12.md`).
**Owner/approver:** Achia · **Executor (when greenlit):** Claude Code

## What it is

Let the user type a caption that sends **together with** a staged image/video in
one message (currently sending is image **or** text, not both).

## Why it's a clean, separate feature

- **App-only.** The send API already accepts `text` + `file` in one request
  (`rx_send_message/api.dart`), so no backend/migration/deploy.
- **Builds on** the composer attachment fix — it assumes the in-composer staged
  layout that fix introduces. So it should ship **after** that fix is on
  `develop` (and ideally released), to keep each feature's branch/PR isolated.

## Rough scope (flesh out when greenlit — do not start without Achia)

- Branch `feat/composer-image-caption` off `develop`.
- While an image is staged, keep the text field active as a caption; on send,
  pass both `messageText` and `messageFile`.
- Update the optimistic insert + message bubble to render caption-under-media
  (verify `inbox_response.dart` / the bubble already supports a text+media
  message — received messages may already).
- Tests: image+caption send calls `onSend` with both; bubble renders caption
  under media; empty-caption still sends image-only.
- Same guardrails as every change: small PR off `develop`, keep
  **"Analyze & Test"** green, app-first release, don't touch
  `receiver_message_widget.dart` / the patent path.

## Isolation rule

This feature gets its own branch, its own PR(s), its own staging TestFlight
verification, and its own line in the release batch — kept independent of the
attachment-fix work and any other in-flight feature.
