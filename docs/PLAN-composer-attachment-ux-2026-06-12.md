# Plan — Composer attachment UX fix ("staged media looks sent") (2026-06-12)

**Author:** Cowork (operator session) · **Executor:** Claude Code · **Owner/approver:** Achia
**Approved design:** Option B — attachment moves *inside* the composer.

## Problem

When a user picks an image/video to send, the preview thumbnail renders **above**
the "Type a message…" bar, detached, in the area where sent messages live. Users
read it as already sent, move on, and the media never goes out (they never tap
send). Confirmed in code: `send_message_widget.dart` `build()` is a `Column`
whose first child is the media preview, sitting above the input `Row`.

## Approved solution (Option B)

Relocate the staged attachment **into** the composer so it unmistakably reads as
"about to send," following the iMessage/Messenger pattern:

- The thumbnail sits inside the composer container, directly attached to the
  text field + send button (not floating in the message area).
- It carries a clear **× remove** control.
- The **send button changes to an active/filled state** when something is staged
  (image and/or text), signalling an action is still required.
- A short "1 photo ready to send" affordance reinforces the staged state.

## Scope at a glance — this is APP-ONLY

- **App:** yes — one widget (`send_message_widget.dart`), used by both private
  (`InboxScreen`) and group (`GroupInboxScreen`) chats. One fix, both screens.
- **Backend / server:** **no change.** The send endpoint already accepts `text`
  + `file` together (verified in `rx_send_message/api.dart`:
  `FormData.fromMap({'text': message, 'message_type': type})` + optional
  `data.files.add('file', ...)`). No migration, no API change, no backend deploy.
- **API shapes:** unchanged → **zero backwards-compat risk** to the live App
  Store app (the A1 concern does not apply here).
- **Patent flow:** untouched. Silent recording is **receiver-side**
  (`receiver_message_widget.dart`); this is the **sender** composer. The only
  link is the send path, which we cover with a regression test.

## Guardrails (from `.claude/skills/clean-code-standards/SKILL.md`)

- Small, single-concern PRs off `develop`; Conventional Commits; keep
  **"Analyze & Test"** green (`dart format` + `flutter analyze` + tests).
- App-first release ordering; do not promote to `main`, touch the App Store, or
  deploy prod — that's Achia + operator at release time.
- `StatefulWidget` config fields are `final`; logic stays out of `build()`;
  DartDoc on public elements; match existing GetX/`rx_*` patterns.

---

## The fix (image-only — single isolated feature)

Keep today's behaviour (send is image **or** text, exactly as now) — change only
*where the preview lives* and *how the send button looks*. This is the minimal
change that fully kills the confusion. Captions are explicitly **not** part of
this feature (see "Out of scope" below).

### F1 — Restructure the composer layout

**Branch:** `fix/composer-staged-attachment-inside`
**File:** `app/lib/features/chat/presentation/widget/send_message_widget.dart`

**Do:**
1. Wrap the input `Row` (attachment button + text field + send button) and the
   staged-media preview in a **single rounded container** so they read as one
   unit. Move the `ValueListenableBuilder<XFile?>` preview from being a sibling
   *above* the `Row` to being an element *inside* that container, directly above
   the text-field row, with a connecting background (use
   `ColorName`/`colors.gen.dart` tokens; dark-theme only per DG4).
2. Keep the **× remove** control on the thumbnail (it already sets
   `widget.image!.value = null`) — restyle it as a small circular button on the
   thumbnail's top corner.
3. Add a compact label beside the thumbnail (e.g. "1 photo ready to send" /
   "1 video ready to send") driven by `mediaType`.
4. **Send-button staged state:** when `image.value != null` *or* the text field
   is non-empty, render the send button in its active/filled style (filled
   circle, accent colour); otherwise the resting style. Drive it off the
   existing `image` notifier + a `messageController` listener.
5. Preserve the existing send logic untouched (the `onSend` → `sendMessageRx` /
   `sendGroupMessageRx` path, `tempId`, progress, success callbacks). Do **not**
   change the empty-send guard's behaviour in this PR.

**Must not:** change the send payload, the API call, the optimistic-insert
contract, or anything in `receiver_message_widget.dart` / the patent path.

**Acceptance:**
- Staged image/video appears **inside** the composer, attached to the input; no
  preview floats in the message list area.
- × clears the staged attachment.
- Send button is visibly active only when there's something to send.
- Sending an image (no caption) and sending text-only both behave exactly as
  before. Verified in both private and group chats (same widget).

### F2 — Widget tests

**Same branch (or a follow-up PR).** Add `app/test/.../send_message_widget_test.dart`
mirroring `lib/` (use `flutter_test` + hand-written fakes; no mocking package —
match the repo). Cover:
- With a staged `XFile`, the preview renders **inside** the composer subtree and
  the remove control is present.
- Tapping remove sets the shared notifier to `null` and hides the preview.
- Send button is in resting state with empty text + no image; active state when
  either is present.
- **Regression:** tapping send with a staged image invokes `onSend` once with the
  file and the correct `mediaType` (proves the send path still feeds the message
  pipeline that the patent loop depends on).

**Acceptance:** `cd app && flutter test && flutter analyze` green locally;
**"Analyze & Test"** green on the PR.

---

## Out of scope — captions are a SEPARATE feature

Achia's call (2026-06-12): ship this image-only fix first; **captions are their
own, isolated feature** — different branch, different plan, shipped later. Do
**not** add any caption behaviour in this work. Capture only: the send API
already accepts `text` + `file` together, so the future caption feature is
app-only too. It's tracked in `docs/PLAN-composer-image-caption-FUTURE.md` and
will build on the in-composer layout this fix introduces.

---

## End-to-end delivery — staging, App Store, server

### Staging (how this gets verified)

1. Merge F1 (+ tests) to `develop` once green. Staging backend auto-deploys on
   merge, but **this is an app change**, so the real validation is on-device:
2. Trigger a fresh **Reacti Staging TestFlight** build
   (`.github/workflows/ios-testflight.yml`, `workflow_dispatch`, pointed at
   `https://staging.reacti.io/api`).
3. Achia installs the Staging build and runs the **on-device checklist** with the
   seeded `smoke-a` / `smoke-b` accounts:
   - Pick an image → confirm it appears **inside** the composer (not floating
     above) and looks clearly un-sent.
   - Tap × → it's removed.
   - Tap send → it actually sends and appears as a sent bubble; recipient gets it.
   - Repeat in a **group** chat (same widget — confirm parity).
   - Send a **text-only** message → unchanged.
   - Quick **patent-flow sanity**: open a received blurred media item → confirm
     the silent-record→reaction loop still works (unaffected, but it's the
     load-bearing path, so eyeball it once).

> Note: the post-deploy smoke (B2) and iOS integration tests (B1) don't yet
> cover this UI, so the on-device check above is the validation until they do.

### App Store (release)

**Reality:** nothing from the rebuild has shipped yet — the live App Store app is
still the OLD `v1.0.9`. The next release is the **first** release of the new app
and ships everything that is on `main` at that moment. So this fix goes out as
part of that first release, not as a standalone update.

**Isolation via the promotion gate (this is how the fix stays unaffected by other
work).** `develop` accumulates everything, but only what is promoted
`develop`→`main` enters the release. To keep this fix insulated from problems in
unrelated work:

- Promote to `main` only the **verified, ready** set — the security hardening
  (Phases A/B) **plus this composer fix**. **Leave unfinished / risky work
  (testing-plan Phase C, the B1/B3 items) on `develop`, unpromoted.** A defect in
  those cannot affect or delay a release that does not contain them.
- Keep this fix as a **single, self-contained commit** (one widget + its tests)
  so it can be promoted or cherry-picked **independently** — it must not depend on
  Phase C or any other in-flight change.
- Because it is **app-only with no backend change**, it is additionally immune to
  the backend/prod-deploy freeze and any backend issue in the other changes.

**The actual gate is DG1 (consent), not the other engineering work.** Achia's
lawyer requires the consent flow in the first new release, so the realistic
release content is **consent (DG1) + this composer fix + the verified security
batch**, cut once consent is in and Achia has verified the fix on staging. (Whether
a release could ever go out *ahead* of consent is a legal call owned by Achia, not
an engineering one.)

- At release time (Achia drives): bump the app version (`app/pubspec.yaml`, today
  `1.0.9+10`), tag on `main`, archive + upload via `ios-release.yml`, submit to
  App Store.
- Add a plain-language line to the "Next release — what's in it" list in
  `PROGRESS.md`: *"Picking a photo/video now shows it inside the message box with
  a lit-up send button, so it's clear it hasn't been sent until you tap send."*

### Server (backend)

- **Nothing to do.** No code change, no migration, no deploy. The production
  Backend Deploy gate is irrelevant to this feature. Because no API shape
  changes, there is also no risk to the OLD live app from this work.

---

## Risk & rollback

- **Risk:** low. UI-layout-only change in one sender-side widget; send logic and
  the receiver/patent path untouched; no server change; covered by widget tests
  and an on-device pass.
- **Rollback:** trivial — revert the single PR. No data, schema, or API
  implications.

## Definition of done

- Staged attachment renders inside the composer in private **and** group chats;
  the "looks already sent" confusion is gone.
- × removes the attachment; send button reflects staged state.
- Image-only and text-only sends behave exactly as before (regression test
  proves the send path is intact).
- `flutter analyze` + tests green; **"Analyze & Test"** green on the PR.
- On-device verified on the Reacti Staging TestFlight build (checklist above).
- `PROGRESS.md` updated; the fix is a single self-contained commit that can be
  promoted/cherry-picked independently of Phase C and other in-flight work; no
  backend change shipped.

---

## Kickoff prompt for Claude Code

```text
Read .claude/skills/clean-code-standards/SKILL.md and
docs/PLAN-composer-attachment-ux-2026-06-12.md. Execute it (image-only).

This is an APP-ONLY change — no backend/API/migration/deploy. Fix the confusing
"staged media looks already sent" composer behaviour using approved Option B:
move the staged attachment INSIDE the composer (iMessage/Messenger pattern).

Branch fix/composer-staged-attachment-inside off develop. Edit only
app/lib/features/chat/presentation/widget/send_message_widget.dart (used by both
InboxScreen and GroupInboxScreen, so one fix covers both):
  - Wrap the staged-media preview + input row in one rounded container; move the
    preview from above the input to inside that container, attached to the text
    field.
  - Keep/restyle the × remove control; add a "1 photo/video ready to send" label.
  - Make the send button show an active/filled state when an image is staged or
    the text field is non-empty; resting otherwise.
  - Do NOT change the send payload, the onSend->sendMessageRx/sendGroupMessageRx
    path, the optimistic insert, or anything in receiver_message_widget.dart /
    the patent flow.

Add app/test widget tests (flutter_test + hand-written fakes, no mocking package):
preview renders inside the composer, × clears it, send-button state toggles, and
a regression test that send with a staged image calls onSend once with the file
and correct mediaType. Run `cd app && flutter test && flutter analyze` — keep
"Analyze & Test" green.

Keep this fix a SINGLE self-contained commit (one widget + its tests) so it can
be promoted/cherry-picked to main INDEPENDENTLY of testing-plan Phase C and any
other in-flight work — it must not depend on them. Achia intends to ship it in
the first release (alongside the DG1 consent flow + the verified security batch)
while leaving unfinished work unpromoted, so don't entangle it.

Guardrails: small PR off develop, Conventional Commits, StatefulWidget config
fields final, DartDoc public elements, match existing GetX/rx_* patterns. Don't
promote to main, touch the App Store, or deploy. When green on develop, tell
Achia it needs a fresh Reacti Staging TestFlight build for the on-device
checklist in the plan, and add the plain-language line to PROGRESS.md's "Next
release" list. Captions are a SEPARATE feature with their own plan/branch — do
NOT add any caption behaviour here; keep this PR strictly image-only.
```
