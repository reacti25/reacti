# PLAN — View-once media ("one-time", both ways) — 2026-07-18

Status: **DRAFT for Achia's review.** No code written. Three research tracks
(client flow, backend flow, screenshot/lifecycle) fed this.

## 0. Decisions locked (2026-07-18)

- **Q1 scope → 1:1 AND groups in v1.** Groups are in. See §5 for the group
  semantics I'm proposing — one open sub-point to confirm.
- **Q2 screenshot → block/blank silently (WhatsApp).** No "you were
  screenshotted" notification. Detection is used only as the iOS *fail-open
  fallback* (if content-blanking breaks, dismiss/destroy the viewer).
- **Q3 media URL → proper authed/signed route.** View-once media never touches
  the public `uploads` dir and is never CDN-cached; served via a short-lived
  signed/streamed endpoint. This is extra backend scope, folded into §5 + §9.

## 1. The feature

A per-send **one-time toggle** on media. When on:

- The media arrives **sealed as normal** (existing blur/patent flow untouched),
  with a small **"1"-in-a-circle badge** marking it one-time.
- Receiver taps → media **auto-opens full-screen** and plays. While in
  full-screen they may linger/replay freely; **screenshots are blocked/blanked**.
  The existing **silent front-camera reaction recording** runs exactly as today.
- Receiver **leaves full-screen** → the media is **destroyed** (server file +
  row, and the local copy). The bubble **re-seals** showing a **"viewed once"**
  state, with the **reaction now attached**. Nobody — receiver or sender — can
  ever reopen the media.
- Sender taps the reaction → it **auto-opens full-screen** and plays; replay
  freely while in full-screen; screenshots blocked.
- Sender **leaves full-screen** → the **entire exchange is destroyed** (reaction
  file + row *and* the already-spent media row), as if it never existed.

"One-time" = **one full-screen session per side**, not one play. Exiting
full-screen is the irreversible, one-way trigger on each side.

## 2. The state machine

```
SENT (one_time=1, sealed, "1" badge)
   │  receiver taps  →  [existing] mark-viewed → unblur → silent reaction record
   │                    [new]      claim: server hard-deletes media file, keeps row
   ▼
FULL-SCREEN VIEW (receiver)   ← screenshots blocked here
   │  receiver exits full-screen
   ▼
SPENT (bubble re-seals: "viewed once" placeholder + reaction attached)
   │  sender taps reaction  →  auto full-screen, replay freely
   ▼
FULL-SCREEN VIEW (reaction, sender)   ← screenshots blocked here
   │  sender exits full-screen
   ▼
GONE (reaction row+file AND media row hard-deleted + broadcast; bubble removed)
```

## 3. What must NOT change (patent guarantee)

The reaction agent confirmed the 8 load-bearing points. The view-once path is
**strictly additive** — it reads a new flag and branches *after* the existing
unblur/record/upload path runs. It never reorders or gates these:

1. `media_seal.dart:12` `isMediaSealed` (true/1 = sealed).
2. `receiver_message_widget.dart` blur gate in `_buildFilePreview` (858-864).
3. `_buildBlurPlaceholder` tap → mark-viewed → unblur → `_fireReactionCapture`
   (1108-1196), incl. the `waitingForSuccess` gating and `!value` stays-blurred.
4. `_fireReactionCapture` `_recordingFired` once-guard + `type:"reaction"` +
   `replyToId` uploads (385-497).
5. Server: `is_viewed` stays **integer**-serialized (live-app crash class).
6. Reaction-count query depends on the reaction row existing at broadcast time
   — media destroy happens *after* the reaction is safely uploaded/echoed.

The regression test CLAUDE.md requires: a full-loop test proving that with
`one_time=1`, the seal → mark-viewed → record → reaction-upload sequence still
fires in the same order, and destroy runs only *after* it.

## 4. Client design

- **New model field** `oneTime` (`dynamic`, mirroring the loose `is_blurred`
  convention) on `Chat` and group `Message`; parsed `1/0/bool`. Threaded into
  `ReceiverMessageWidget` / `SenderMessageWidget` from both inbox screens.
- **"1" badge**: small overlay on the blur placeholder when `oneTime` and still
  sealed.
- **Full-screen viewer**: reuse `FullScreenImageViewer` for images; **build a
  full-screen video route** (none exists today — video plays inline via Flick).
  The viewer owns the screenshot-protection lifecycle and the on-exit destroy
  signal. Must not dispose the **shared** `VideoControllerCache` controller.
- **Branch point**: in the mark-viewed success block (`receiver_message_widget.dart:1152-1173`),
  after the existing unblur+record dispatch, if `oneTime` → push the full-screen
  viewer instead of inline media.
- **Screenshot protection**: `no_screenshot` (see §6), `screenshotOff()` on
  viewer open, `screenshotOn()` on close — scoped to the viewer only.

## 5. Server design

Reuses the existing seal + mark-viewed + reaction path; adds a destroy step
*after* it. Template for hard-delete already exists: `PruneStaleStagingChat`
(`forceDelete()` + `unlink(public_path($file))` + child-row cleanup).

- **New column** `one_time` (boolean, default false) on `chats` and
  `group_messages`. Additive migration; serialized as int like `is_viewed`.
- **Media destroy on receiver view** — inside `ChatService::markAsViewed()`,
  *after* the existing `is_viewed/is_blurred` write and `MessageReadEvent`
  broadcast: if `one_time`, `unlink` the file (+thumbnail) and null the `file`
  column (keep the row as the "viewed once" placeholder carrying the reaction).
  Atomic claim — a conditional `UPDATE ... WHERE is_viewed=0` so a replayed
  request can't re-fetch.
- **Reaction destroy on sender view** — 1:1 has **no** sender-side
  mark-viewed-reaction endpoint today; add one (or scope `mark-viewed` to
  reaction rows). On consume: `forceDelete()` the reaction row + `unlink` its
  file, then resolve its `reply_to_id` parent and `forceDelete()` that row too;
  broadcast `MessageDeletedEvent` for both so clients drop them.
- **Groups (in v1 per Q1)** — proposed semantics, one point to confirm:
  - Each recipient gets their **own** one-time full-screen view (per-recipient
    `is_viewed`/`is_blurred` in `group_message_user_statuses`), and each records
    **their own** reaction — same as a normal group media message today.
  - The shared media **file** is hard-`unlink`ed once **every** recipient has
    viewed it once (last-viewer-wins), OR when the message ages out — because
    one physical file backs all recipients, it can't be deleted after the first
    viewer without breaking the others. Until then, each recipient who has
    already viewed sees the "viewed once" placeholder; the file simply isn't
    fetchable by them again (server refuses a second claim per user).
  - Each **reaction** self-destructs when the **sender** views it once (as in
    1:1). When the last reaction is consumed, the media **row** is force-deleted.
  - **TTL (locked 2026-07-18): 48 hours.** The shared file is deleted when all
    recipients have viewed **or** 48h after send, whichever comes first. A
    janitor (P4) enforces the TTL for stragglers who never open it.
- **Signed/authed serving (per Q3)** — view-once uploads go to a **non-public
  disk** (not `public/uploads`), so no `asset()` URL and nothing for Cloudflare
  to cache. A new authed endpoint issues a **short-TTL signed URL** (or streams
  the bytes) only on a legitimate, not-yet-spent claim. The claim is the
  security boundary, not the URL. On consume, the stored object is deleted.

## 6. Screenshot protection — the honest ceiling

- **Android**: `FLAG_SECURE` genuinely blocks screenshots **and** screen
  recording, per-window. Solid.
- **iOS**: Apple provides **no way to block the screenshot gesture** — but the
  `isSecureTextEntry` secure-layer trick (what WhatsApp and the plugin use)
  **blanks our content out of the screenshot and screen recording** (comes out
  black). Plus we can detect recording (`UIScreen.isCaptured`) and detect a
  screenshot after the fact.
- **Neither platform** can stop a **second phone photographing the screen**, a
  jailbroken/rooted device, or AirPlay capture. This is the same ceiling
  WhatsApp lives with. The honest promise is **"protected against casual OS
  capture,"** never "impossible to capture."
- **Package**: `no_screenshot` 1.2.0 (actively maintained, both platforms, both
  block *and* detect, per-screen toggle). Native Swift/Kotlin but **not** the
  too-new-SDK class that broke `connectivity_plus` — still, **pin exact, verify
  on the CI Xcode runner before merge, and add a detect-and-destroy fallback**
  so if Apple renames the internal view and blanking fails-open, we fall back to
  dismissing/destroying the viewer on a detected capture.

## 7. The real guarantee is server-side

On-device screenshot blocking is defense-in-depth, not the guarantee. The
guarantee is: **the bytes are gone from the server after one legitimate view.**
Because our reaction flow already fires mark-viewed at tap, the media is already
"claimed" at that moment — we destroy the server file there (atomic claim), and
the client renders its full-screen session from the bytes it already fetched.
On exit, the client drops its local copy. This matches the UX *and* closes the
"force-quit before the delete call" replay loophole (the file is already gone
server-side; a re-open finds nothing).

## 8. Serving (resolved: proper authed route, Q3)

View-once uploads are stored on a **private disk**, never `public/uploads`, so
there is no `asset()` URL and nothing reaches Cloudflare. A new authed endpoint
returns a **short-TTL signed URL** (or streams bytes directly) only when the
caller has a valid, unspent claim on that item. The **claim** (atomic
`is_viewed 0→1`) is the boundary; the signed URL is a thin expiring delivery
layer. On consume, the private object is deleted. This closes the
permanent-public-URL + CDN-cache leak entirely.

## 9. Phasing

Groups are in v1 (Q1), so each phase now covers 1:1 **and** group.

**P1 — DONE (merged to develop 2026-07-18):** `one_time` column (chats +
group_messages, PR #357), client `oneTime` field + "1" badge (#358), composer
toggle + send plumbing (#359). Ships dark; a one-time send currently behaves
exactly like ordinary sealed media + the badge, served from the public disk.

**Finding that folds old P1b into P2:** the client loads chat media with
`CachedNetworkImage` and **no auth header**, and it **caches to disk**
(`inbox_custom_network_image.dart:59`). So the private-disk + authed-serving
work (old P1b) cannot ship on its own: switching one-time media's URL to an
authed endpoint would (a) fail to load inline without a bearer header, and
(b) leave the decrypted image in the on-device cache after "destroy" — a leak.
Both are only solved together with the P2 full-screen viewer, which must fetch
with auth **and** bypass the disk cache and drop its bytes on exit. So private
serving now lives inside P2.

**P2 — DONE (merged 2026-07-18/19):** private-disk storage + authed streaming
(#361), non-caching screenshot-protected full-screen viewer (#362), fetch-window
claim + consume/destroy for 1:1 (#363 backend, #364 client incl. the sender
placeholder) and group per-recipient (#365). Patent suite green throughout. The
whole *view loop* works: send with the "1" toggle → badge → tap → authed
non-caching protected viewer while the reaction records → close → destroyed
(force-quit-safe via the window) → "viewed once" placeholder both sides.

1. **P3 — sender reaction one-time + total erasure.** ⚠️ **Touches the patented
   reaction path** — needs the full-loop regression test (CLAUDE.md). When a
   reaction replies to a one-time message, the reaction itself becomes
   one-time: stored privately, sealed for the media-sender, opened once in the
   protected viewer; on close it destroys the reaction **and** the parent media
   row and broadcasts the delete so the whole exchange vanishes. 1:1 + group.
2. **P4 — hardening.** iOS fail-open fallback (detected capture → dismiss +
   destroy), the **48h TTL janitor** (extends the staging-prune pattern to
   sweep aged one-time media/rows), CDN/cache eviction audit.

Each phase ships to staging behind the toggle before the next.

## 12. Destroy model — LOCKED (fetch-window, both types)

Chosen 2026-07-18. Video streams via HTTP range requests (many partial
fetches), so delete-on-first-fetch would break playback. Instead:

- **Claim opens a window.** When the receiver's `mark-viewed` fires on a
  one-time message, the server — after the existing `is_viewed`/`is_blurred`
  write and broadcast — opens a short one-shot **fetch window** (a
  `consume_deadline` timestamp). The reaction record + unblur run as today.
- **Streaming endpoint serves only within the window** to a participant whose
  claim is open. Outside it → 404, file gone.
- **Destroy = window-close OR viewer-exit, whichever first.** The client signals
  on viewer exit (explicit destroy call); a server-side janitor deletes any file
  whose `consume_deadline` has passed. **Force-quit before the signal still
  deletes** via the deadline — that's the force-quit safety.
- **Group:** each recipient's `mark-viewed` opens their own window against the
  shared file; the physical file is deleted when **all** recipients' windows
  have closed/consumed, or the 48h TTL — whichever first (plan §5).
- Residual: within the short window the same authenticated receiver could
  reopen and re-view. Accepted (this option over strict delete-on-fetch); the
  window is seconds-to-a-couple-minutes and the non-caching viewer keeps nothing
  on disk.

## 11. Open decision for P2 — one-time media caching

`CachedNetworkImage` persists to disk, which defeats "destroyed after view". The
one-time full-screen viewer must not leave bytes behind. Options:
- **Non-caching fetch** (recommended): load one-time media with a plain,
  memory-only image (bearer header via Dio), never touching the disk cache, and
  drop it on viewer exit. Nothing to evict.
- **Cache + explicit eviction**: keep the cache but call
  `CachedNetworkImage.evictFromCache(url)` on destroy. Simpler load path, but
  relies on eviction actually running (force-quit mid-view leaves it cached).
Recommend non-caching — for a privacy feature, never-write beats
write-then-delete.

## 10. Decisions — ALL RESOLVED (see §0)

Q1 → 1:1 + groups. Q2 → silent block/blank. Q3 → authed/signed route.
Group TTL → **48h** (delete on all-viewed or 48h after send, whichever first).
Plan is build-ready; P1 is the next step.
