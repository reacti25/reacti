# PLAN — WhatsApp-style media send (2026-07-16)

_Approved by Achia 2026-07-16: full WhatsApp parity, **one shared caption**,
**each selected item is its own sealed media message** (each records a reaction
when the recipient opens it — the patented flow must run per image)._

## Current Reacti flow

Composer ＋ → sheet (Gallery / Camera).
- Gallery → `wechat_assets_picker` grid, **`maxAssets: 1`** → `MediaPreviewScreen`
  (image/looping video, ✕ / "Use") → single file staged as a **thumbnail chip**
  in the composer; caption is whatever you type in the normal text box → send.
- Camera → `CameraCaptureScreen` → same preview → Use/discard (discard re-opens
  camera).

Send path (`send_message_widget.dart`): `_handleSend` → optimistic echo via
`onSend` (screen inserts into `cList`) → `_compressThenSend` →
`sendMessageRx.sendMessage` / `sendGroupMessageRx.sendMessage`
(`type: "normal"`, `file`, `message`). **The backend seals every media message
(`is_blurred`)**; the client reads it via `isMediaSealed`. So sealing +
reaction-recording is per media message and server-driven — a batch just needs
to send each item through this same call.

## WhatsApp flow (target)

1. In-app gallery grid: recents, album dropdown, **camera tile**, **multi-select**
   with numbered badges (cap ~30).
2. Full-screen **review screen**: media fills the screen; **caption field + Send**
   pinned at the bottom; **filmstrip** of selected items above it (swipe between,
   **remove**, **＋ add more**).
3. **Edit toolbar**: crop/rotate, draw/doodle, add text, stickers/emoji, HD toggle.
4. Send → items post as a batch.

## Non-negotiable (patent)

Every item in a batch must be sent via the existing `sendMessage` media path so
it is sealed and fires `mark-viewed` → `recordVideoSilently` when opened. The
multi-send loop must NOT introduce a non-sealed send path. Regression test must
prove N images → N sealed media messages, each reaction-capable. (CLAUDE.md
north-star.)

## Phases (each ships to staging)

### Phase 1 — the flow (no new dependency)
- **1a Picker**: `maxAssets` → 30, `requestType: common`, add a camera tile in
  the grid (`AssetPickerConfig.specialItemBuilder` / `specialItemPosition`).
- **1b Review screen** (`MediaReviewScreen`, replaces `MediaPreviewScreen` for
  the gallery/camera path): current item preview (image / looping video),
  bottom **shared caption `TextField` + Send**, **filmstrip** row (thumbnails,
  active highlight, ✕ per item, ＋ add-more → re-opens picker and merges).
- **1c Multi-send**: on Send, loop the selected items; for each, run the SAME
  optimistic-insert + `sendMessage` the single path uses, with the shared caption
  as the message text (attach caption to each item, per approval). Reuse the
  existing rx calls — no new send path.
- **1d Tests**: extend the patent interactive/regression test to a 2–3 item
  batch (each sealed + each fires the reaction loop); widget tests for the review
  screen (caption, remove, add-more, send count).

### Phase 2 — the editor (adds a package)
- Integrate an image editor (candidate: `pro_image_editor`) for crop/rotate,
  draw, text, emoji/stickers; wire an **HD** quality toggle. Editing writes a new
  file that replaces the item in the filmstrip before send.

## Open/verify during build
- Confirm backend seals media on send by default (it does today for single
  send); no backend change expected for Phase 1.
- Video in a multi-batch: keep per-item type; each sent with its own media type.
- Cap large batches with a clear count; `log()` anything dropped.
