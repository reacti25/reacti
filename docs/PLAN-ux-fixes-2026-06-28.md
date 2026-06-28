# PLAN — UX fixes batch (read receipts, OTP destination, bottom bar, chat filters, contacts skip)

**Date:** 2026-06-28
**Author:** Achia (decisions) + Claude (research, design, drafting)
**For:** Claude Code
**Status:** Approved for implementation, phase by phase. Do **not** start a phase
without confirming with Achia, per `CLAUDE.md`.

---

## 0. How to use this document

This plan covers five independent UX problems in the Reacti app. Each is small on
its own. They are sequenced into phases below; **do one phase per branch / PR** and
get the verification checklist green before moving on.

Read these first, in order:

1. `CLAUDE.md` (repo root) — conventions, the north-star reaction flow you must not break.
2. `docs/conventions.md` — commit format, Dart/PHP style, the rule about one response
   envelope and real HTTP status codes.
3. This file.

Branch naming: `feat/ux-<short-name>` (e.g. `feat/ux-read-receipts`). Conventional
Commits. Each PR description must state which phase it implements and paste the
verification checklist with results.

Hard rules that apply to every phase:

- **Do not touch the patent flow** (silent front-camera reaction recording in
  `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`). If a
  change comes near the blur/unblur, `mark-viewed`, reaction upload, or the
  broadcast events, write/extend a regression test that exercises the full loop.
- `dart format .` and `flutter analyze` must pass (app). `./vendor/bin/pint` must
  pass (backend). No `dd()` left behind, no committed secrets, no TLS weakening.
- This app is **live on the App Store** and ships app-then-backend
  (release the iOS app first, then deploy backend). Any change that needs a new
  backend field must be **backwards-compatible**: old app builds must keep working
  when the new backend ships, and the new app must tolerate the old backend
  (treat missing fields as the safe default).

> **Screenshots:** referenced images live in
> `docs/screenshots/ux-fixes-2026-06-28/`. If they are not yet present, see the
> `README.md` in that folder — Achia will drop them in. The text descriptions
> below are sufficient to implement even if an image is missing.

---

## Phase 1 — Read receipts (sent / delivered / seen)

### The problem

When you send a message you only ever see **one** blue check. It never becomes a
second check when the recipient actually reads it, so there is no "seen"
confirmation like WhatsApp's double blue ticks.

![Read receipts — only one check ever shows](screenshots/ux-fixes-2026-06-28/01-read-receipts.png)

### Correct design (approved)

Three distinct, well-understood states, applied **differently** to text vs media vs
reactions:

1. **Text messages → WhatsApp-style single → double check.**
   - In flight (optimistic/local): the small spinner (current behaviour).
   - Sent/delivered: **one** check.
   - Read/seen by recipient: **two** checks, tinted (e.g. the app's lime
     `allPrimaryColor` or blue — pick one and use it consistently).

2. **Media messages → no read receipt at all.**
   Rationale: if the recipient opened the media, a reaction was captured and sent
   back, so the reaction itself *is* the proof of "seen". Don't add a tick to media
   bubbles; it would be redundant and noisy.

3. **Reaction videos → a small, elegant "seen" dot.**
   When you send a reaction, show a tiny **grey dot** next to it that turns **green**
   once the other person has watched your reaction. Small and unobtrusive — not a
   second check, just a status dot. This is the only "did they see my reaction"
   signal in the app, so it should be quiet but present.

4. **Privacy & Security setting → "Read receipts" toggle.**
   Add a toggle in the privacy/security area. Behaviour is **reciprocal**, like
   WhatsApp: if a user turns read receipts **off**, they stop sending the
   read/seen signal **and** stop seeing it from others. Group behaviour: keep it
   simple for v1 — the toggle suppresses the per-message seen state everywhere.
   Default: **on**.

### What already exists (use it, don't reinvent)

- The single check is rendered in two places, both via `Icons.check_rounded`
  (`Colors.blueAccent`):
  - `app/lib/features/chat/presentation/widget/sender_text_bubble.dart`
    (the extracted, unit-testable text bubble — has `isLocal` already).
  - `app/lib/features/chat/presentation/widget/sender_message_widget.dart`
    (around the "Timestamp + sent indicator" Row).
- The message models **already carry a viewed flag**:
  `inbox_response.dart` and `group_inbox_response.dart` both expose `isViewed`
  (currently `dynamic`, JSON key `is_viewed`). The "seen" signal therefore already
  reaches the client for received messages.
- The recipient already calls `mark-viewed` (`POST /auth/chat/mark-viewed/{id}`)
  and the backend broadcasts via Pusher. That is the event that should flip a
  **sent** message from one check to two on the sender's device.

### Implementation steps

1. **Confirm the data path for the sender.** Trace how a sent message learns it was
   viewed. The recipient's `mark-viewed` must result in a broadcast the *sender*
   receives (a `MessageViewedEvent`-style event on the sender's private channel) so
   the sender's bubble can update live. If that broadcast does **not** exist yet,
   add it on the backend (see step 5) — do not poll.
2. **Model:** make the sent/outgoing message hold a typed `isViewed`/`isSeen`
   bool. Normalise the existing loose `dynamic is_viewed` (it's loosely typed for a
   reason — keep tolerating `1`/`true`/`"1"`), but expose a clean `bool get isSeen`.
3. **Text bubble UI:** in `sender_text_bubble.dart` and the Row in
   `sender_message_widget.dart`, render: spinner (local) → single check (sent) →
   double check (seen). Centralise this into one small widget, e.g.
   `MessageStatusTicks(status)`, so both call sites and tests share it. Respect the
   read-receipts setting.
4. **Reaction "seen" dot:** in the reaction message widget, add the grey→green dot
   driven by the same viewed signal for `type: "reaction"` messages. Keep it tiny.
5. **Backend (only if the sender-side broadcast is missing):** add a broadcast event
   fired from the `mark-viewed` controller to the **sender's** channel carrying the
   message id. Keep the existing response envelope `{success, message, data, code}`
   and real status codes. Backwards-compatible: the event is additive.
6. **Privacy setting:** add the "Read receipts" toggle (app UI in the privacy
   screen + persisted server-side preference if receipts are enforced server-side;
   if enforcement is purely client-side for v1, persist locally and gate both
   sending the `mark-viewed`-derived broadcast suppression and rendering). Document
   which side enforces it in the PR.

### Verify before merge

- Send a text message between two devices/simulators: sender sees spinner → one
  check → **two checks** within a second of the recipient opening the chat.
- Media bubbles show **no** tick.
- Send a reaction; the dot flips grey → green when the other side watches it.
- Toggle "Read receipts" off on device A: A no longer turns B's messages to
  "seen", and B no longer sees A's messages as "seen" (reciprocal).
- Unit tests on the new `MessageStatusTicks` widget for all three states.
- **Regression:** the full reaction loop (open media → silent record → upload →
  broadcast) still passes its end-to-end test. This phase touches code adjacent to
  it, so this check is mandatory.
- `flutter analyze` + `dart format .` clean; `pint` clean if backend changed.

---

## Phase 2 — OTP screen says where the code went

### The problem

The signup "Verify OTP" screen shows four code boxes and a countdown, but never
tells the user **where** the code was sent. People sit and wait — sometimes for an
SMS that will never arrive, because the code actually goes to their **email**.

![OTP screen with no destination shown](screenshots/ux-fixes-2026-06-28/02-otp-no-destination.png)

### Correct design (approved)

- **Keep email as the OTP channel.** Email is free and already built. After
  research, **both SMS and WhatsApp OTP cost money per message** (and cost *more*
  internationally), so per Achia's "if it costs money we won't take it" rule we do
  **not** add them now.
- **Make the screen honest about the destination.** Under the "Verification Code"
  heading, show a clear line:
  *"We emailed a 4-digit code to **a•••@gmail.com**"* (mask the local part).
- Keep "verification code" wording (already correct). Keep the existing expiry
  countdown. Add/keep a **Resend** affordance tied to that timer.
- **Phone stays optional at signup** (good for a privacy-first app). Because phone
  is optional, it could never be the only channel anyway — email covers everyone.

### What already exists

- `app/lib/features/auth/presentation/signup_verify_otp/signup_verify_otp_screen.dart`
  **already receives `widget.email`** (its doc comment literally says "the OTP was
  sent to this address"). The data is in hand — it just isn't displayed.
- Sibling screen for the forgot-password flow:
  `app/lib/features/auth/presentation/verify_otp/verify_otp_screen.dart` — apply the
  same destination line there for consistency.

### Implementation steps

1. Add a masked-email helper (e.g. `a•••@gmail.com` from `achia...@gmail.com`).
   Keep it dumb and safe: show first char + domain, mask the middle.
2. In the signup verify screen, insert a subtitle `Text` under "Verification Code"
   using `widget.email`.
3. Do the same in the forgot-password verify screen (it should know the email/
   destination it sent to; thread it through if not already).
4. Confirm a **Resend** control exists and is wired to the existing resend RX
   (`rx_resend_forget_otp`, and the signup equivalent); if missing, add it.
5. Leave a short `// FUTURE:` note + a stub section in this doc (see "Deferred")
   pointing at where a channel picker (email vs paid SMS/WhatsApp) would slot in,
   so the option isn't lost.

### Verify before merge

- Sign up with a new email → verify screen shows "emailed a code to <masked
  email>". No mention of SMS anywhere.
- Forgot-password flow shows the same destination line.
- Resend works and respects the countdown.
- `flutter analyze` + `dart format .` clean. No backend change required.

---

## Phase 3 — Bottom bar: remove the center "+" hero button

### The problem

The bottom bar's center button is a "+" that creates a **new group**. Creating a
group is nowhere near the app's core feature, so it shouldn't be the visual hero of
the whole app. Also, starting a 1:1 chat requires a friend request + approval (it's
not a "compose" action), and sending media belongs **inside** an existing chat — so
a generic compose/hero button doesn't map to anything that should be primary.

### Correct design (approved)

- **Remove the center hero item entirely.** The bottom bar becomes **four plain,
  equal tabs**, no special center styling, no route-on-tap trickery:

  **Chat · Friends · Request · Profile**

- Group creation moves to a contextual action (see Phase 4 below — a small header
  "+" inside the Chats screen), not the bottom bar.
- "Friends" remains the real place to add people / start talking to someone;
  "Request" remains the incoming-request inbox. This is already how the app is
  structured — we are just dropping the artificial 5th center item.

### What exists today

`app/lib/features/navigation/presentation/navigation_screen.dart`:

- `pages = [ ChatScreen(), FriendsTabScreen(), NewChatScreen(), RequestScreen(), ProfileScreen() ]`
  — index **2** (`NewChatScreen`) is never actually shown.
- `_buildNavItem` special-cases `index == 2` ("New Chat"): it hides its label and,
  on tap, calls `NavigationService.navigateTo(Routes.createGroupRoute)` instead of
  switching tabs. **That is the button to remove.**

### Implementation steps

1. Remove the center item: delete the `index == 2` branch from `_buildNavItem`'s
   `onTap`, drop the `isNewChatIcon` special styling, and remove the `NewChatScreen`
   entry from `pages` so the four remaining tabs are Chat(0), Friends(1),
   Request(2), Profile(3). Renumber indices accordingly.
2. Make all four items render identically (icon + label, selected tint).
3. Re-home "create group": expose it as a small header action on the Chats screen
   (see Phase 4) routing to `Routes.createGroupRoute`. Don't lose the entry point.
4. If `NewChatScreen` is now fully unreferenced, leave the file but remove it from
   the nav; note in the PR whether it's dead code to delete later (don't delete in
   this PR unless trivially safe).

### Verify before merge

- Bottom bar shows exactly four evenly-spaced tabs; tapping each switches body.
- No center "+"; nothing in the bar opens create-group anymore.
- Create-group is still reachable from the Chats screen header.
- `flutter analyze` clean (watch for unused imports/variables after removal).

---

## Phase 4 — Chats screen: groups as a top filter + Unread

> Do Phase 4 in the **same branch or right after** Phase 3 — they both reshape the
> Chats screen and its header.

### The problem

There is no separate place for groups. The Chats list mixes 1:1 chats and group
chats together, with no way to see just groups (like WhatsApp), and no way to see
just the conversations that need attention.

### Correct design (approved)

Keep one Chats screen, add **filter chips at the top** (WhatsApp-style), **not** a
new bottom tab:

- **All** (default) — 1:1 + groups, current behaviour.
- **1:1** — direct conversations only.
- **Groups** — group conversations only.
- **Unread** — conversations with anything pending the user's attention.

**"Unread" semantics (Reacti-specific):** treat a conversation as unread if it has
**unread text, unopened media, OR an unwatched reaction**. Fold all three into the
one filter rather than three separate chips. Surface a small **count badge** (on the
chip, and optionally on the Chat bottom-tab) the way WhatsApp does.

> Label note: Achia was deciding between "Unread" and "Unseen". This plan uses
> **"Unread"** as the visible label (most familiar) with the broad definition
> above. If Achia prefers the word **"Unseen"**, change only the label string.

A small **"+" / new action in the Chats screen header** hosts "New group" (and, if
desired later, "New chat" → Friends). This replaces the removed bottom-bar button.

### What exists today

- `app/lib/features/chat/presentation/chat_screen.dart` lists every conversation and
  already branches on `data.type == "group"` when routing
  (`GroupInboxScreen` vs `InboxScreen`).
- `app/lib/features/chat/model/chat_list_response.dart` → `Chat.type`
  (`"group"` for groups) distinguishes the two kinds. **1:1 vs Groups filtering can
  be done entirely client-side** with this field — no backend change.
- **There is no unread/unseen field on `Chat`.** The list model has no unread count.
  So the **Unread filter needs a data source.**

### Implementation steps

1. **Filters UI:** add a chip row at the top of `ChatScreen` (All / 1:1 / Groups /
   Unread). Hold the active filter in screen state. Filter the existing list:
   - 1:1 → `chats.where((c) => c.type != "group")`
   - Groups → `chats.where((c) => c.type == "group")`
   - All → no filter.
2. **Unread data:** add an unread indicator to the chat-list payload. Preferred:
   backend adds `unread_count` (or `has_unread`) per conversation on the chat-list
   endpoint, computed from unread messages **and** unopened media **and** unwatched
   reactions. Add the field to `Chat` (`unreadCount`/`hasUnread`), defaulting to
   `0`/`false` when absent so old/new combos are safe. Unread filter →
   `chats.where((c) => (c.unreadCount ?? 0) > 0)`.
   - If a backend change is out of scope for this phase, ship All/1:1/Groups now and
     land Unread in a follow-up; **don't fake unread client-side** in a way that
     drifts from the server.
3. **Count badges:** render the chip count and (optional) the Chat tab badge from
   the summed unread.
4. **Header action:** add the small "+" to the Chats header → "New group"
   (`Routes.createGroupRoute`). This is the new home for create-group from Phase 3.
5. Keep RTL correct — the app has Hebrew users; chips and badges must lay out
   correctly in RTL.

### Verify before merge

- All / 1:1 / Groups instantly filter the list correctly (test an account that has
  both kinds).
- Groups filter matches what WhatsApp's "Groups" does — only group rows.
- Unread shows only conversations with pending text/media/reactions; opening one
  clears it from the filter and decrements the badge.
- Create-group reachable from the header "+".
- RTL layout verified (Hebrew). `flutter analyze` + `dart format .` clean;
  `pint` clean if the endpoint changed; backwards-compat of the new field confirmed.

---

## Phase 5 — Contacts permission: add "Not now"

### The problem

The first-time "share your contacts" screen offers only **"Choose contacts"** and
**"Share all N contacts"**. There is no way to **skip**. A user who doesn't want to
share contacts feels trapped — and research shows a missing skip makes people
abandon onboarding entirely.

![Contacts share screen with no skip option](screenshots/ux-fixes-2026-06-28/03-contacts-no-skip.png)

### Correct design (approved)

Add a clear, clean **"Not now"** action alongside the two existing buttons. Clean
and simple — no other change. Tapping it dismisses the contacts ask and proceeds
into the app; the user can share contacts later. It must be visually obviously a
neutral/secondary action (e.g. a plain text button under the two primary buttons).

### Where it lives

**Correction (2026-06-28):** the "two CTAs" screen in the design was the **native
iOS contacts permission dialog**, not an in-app two-button screen — no such widget
exists in the code. What actually happens: opening the **Friends tab**
auto-fires the OS contacts permission request (twice — once in
`friends_tab_screen.dart`'s `initState` and once in the **Contacts** sub-tab
`find_screen.dart`'s `initState`). There is no skip.

So the fix is to **prime** instead of editing a dialog we don't own:

- `app/lib/features/friends/presentation/friends_tab_screen.dart` — stop the
  auto-request on tab open.
- `app/lib/features/friends/presentation/find_screen.dart` — the Contacts sub-tab;
  this is where the priming intro + "Not now" live.

### Implementation steps

1. In `friends_tab_screen.dart`, remove the auto contacts-permission request from
   `initState` (the discarded `getContacts()` call and its now-dead method/imports).
2. In `find_screen.dart`, stop requesting on `initState`. Instead do a **silent**
   permission status check (`permission_handler`, no dialog): if already granted,
   behave as today; otherwise show a **priming intro** — short explainer, a primary
   **"Find friends"** button (the only thing that fires the OS dialog), and a
   secondary **"Not now"**.
3. "Not now" persists a skip flag (`kKeyContactsSkipped` in `GetStorage`) and never
   fires the OS prompt. After a skip, later launches show only the compact manual
   "Find friends" entry point — no re-nag. Granting later still works via that button.
4. Keep copy short and RTL-correct (Hebrew users) — centered, direction-agnostic.

### Verify before merge

- The screen shows three options: Choose contacts / Share all / **Not now**.
- "Not now" proceeds into the app and does **not** trigger the OS contacts prompt.
- Re-launching doesn't force the contacts screen again after a skip.
- RTL layout verified. `flutter analyze` + `dart format .` clean.

---

## Suggested execution order

1. **Phase 5 (contacts "Not now")** — smallest, isolated, pure client. Good warm-up.
2. **Phase 2 (OTP destination)** — small, client-only, no backend.
3. **Phase 3 (remove center button)** — client-only nav change.
4. **Phase 4 (chat filters + unread)** — builds on Phase 3's header; may need a
   small backend field for Unread.
5. **Phase 1 (read receipts)** — most involved; touches code near the patent flow
   and likely needs a backend broadcast. Do it last, with the most care and the
   mandatory regression test.

One branch + PR per phase. Confirm with Achia before starting each phase.

---

## Deferred / future (captured so we don't lose it)

- **Paid OTP channels:** a channel picker (Email vs SMS vs WhatsApp) on the verify
  screen. Blocked on a decision to accept per-message cost. SMS and WhatsApp
  Business both bill per message and cost more internationally. If revisited, pick a
  provider, add international phone input (country-code picker, E.164 storage), and
  keep email as the free fallback.
- **Per-group read receipts** detail (who-saw-it lists) — out of scope for v1's
  simple reciprocal toggle.
- **Delete `NewChatScreen`** if it's confirmed dead after Phase 3.

---

## Open question for Achia

- Phase 4 label: **"Unread"** (used here) vs **"Unseen"** — confirm the word.
- Phase 1: where is the read-receipts toggle enforced — client-side only for v1, or
  server-enforced? (Affects whether a backend preference field is needed.)
