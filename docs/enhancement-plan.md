# Enhancement plan — the functionality phase

This plan turns `docs/code-quality-backlog.md` into sequenced, test-first
work. It is the successor to the refactor plans
(`docs/refactor/*-refactor-plan.md`): those were strictly
behaviour-preserving; **this phase deliberately changes behaviour** —
that is the point.

## Operating rules

1. **Test-first, CI-gated.** For every change, the test that proves it
   lands in CI **green before** the production change is made. Where a
   change needs test infrastructure that does not exist yet, that
   infrastructure is built and wired into CI as its own PR *first*
   (each phase below names what it needs and whether it is new).
2. **Pin-then-update.** A bug fix changes behaviour, so it will break
   the test that pinned the *old* (buggy) behaviour. Rewrite that test
   to assert the *correct* behaviour in the **same PR** — never delete
   or skip it.
3. **One concern per PR.** Small, reviewable PRs. A phase is several
   PRs, not one.
4. **Patent flow is load-bearing.** Any PR touching `send` /
   `markAsViewed` / the blur flags / `recordVideoSilently` re-runs the
   patent suites. See EP4.
5. **Decision gates** (`DG#`, listed at the end) are product / legal /
   business calls. Engineering proceeds around them; the gated item
   waits for the decision. They are flagged, not guessed.
6. Branch `enhance/epN-*` or `test/epN-*` off `develop`; Conventional
   Commits; merge when both required checks are green.

## Test environments — current state

| Environment | Status |
|---|---|
| Backend PHPUnit (`backend/tests/{Unit,Feature}`, `phpunit.xml`, `php artisan test`) | **exists** |
| App `flutter_test` + `pumpInApp` harness (`app/test/support/widget_harness.dart`) | **exists** |
| App GetStorage fixture (`app/test/support/test_storage.dart`) | **exists** |
| Backend static analysis (PHPStan/Larastan) | **missing — build in EP0** |
| Native app build verification in CI | **missing — build in EP0** |
| `InboxScreen` / `GroupInboxScreen` integration harness (fake Pusher + camera + rx) | **missing — build in EP4** |
| Backend service-level unit tests without framework boot | **partial — facade fakes work now; true DI in EP7** |

---

## EP0 — CI & test-infrastructure foundation

**Goal:** put the tooling and gates in place so every later phase can be
proved. No product behaviour changes. Do this phase first.

**Work (each a PR):**

* Make **both** required checks (`PHP Tests`, `Analyze & Test`) always
  report — add a no-op success job on the path that is currently
  filtered out — so branch protection works without `--admin` merges
  (backlog §11).
* Add **PHPStan / Larastan** to `backend-ci.yml` with a baseline
  capturing the current state; the gate fails only on *new* violations
  (backlog §10).
* Add a `dart format --set-exit-if-changed` gate and re-enable
  `flutter analyze` strictness in `flutter-ci.yml` (backlog §11).
* Re-enable a native build job — `flutter build apk --debug` — so
  compile breaks are caught; open a tracked ticket for the disabled iOS
  build (backlog §11).
* Add `composer audit` to `backend-ci.yml`; add `.github/dependabot.yml`
  for `composer` / `pub` / `npm` / `github-actions` (backlog §11).
* Add coverage **reporting** to both pipelines (no threshold yet);
  introduce a low floor and ratchet it up in later phases (backlog §10).
* Point `deploy-dashboard.yml` at `develop` instead of the stale
  `feature/test-environment` branch (backlog §11).

**Test environment:** this phase *is* the test-environment work; it is
verified by the workflows themselves going green.

**Blocked item:** switching CI from `composer update` to
`composer install` waits on **DG8** (obtain the original
`composer.json`).

**Risk:** low — tooling only.

---

## EP1 — Security: exploitable-now criticals

**Goal:** close the holes that are attackable today. Highest priority.

**Items (backlog §1):**

* Delete the unauthenticated maintenance routes in
  `backend/routes/web.php` (`/run-migrate-fresh` et al.).
* Add `throttle:` middleware to every auth/OTP route + an attempt
  counter on the cached OTP.
* Stop returning `otp` in `forgot-password` / `resend-otp` /
  `resend-register-otp` response bodies.
* Remove `MyHttpOverrides` (the app-wide TLS-validation bypass) from
  `app/lib/main.dart`.
* Move the auth token to `flutter_secure_storage`; make
  `totalDataClean()` actually erase token / user id / FCM token and
  rebuild the Dio client unauthenticated.

**Test environment:** existing (backend PHPUnit Feature tests; app
`flutter_test`). No new infrastructure.

**Tests written first:**

* Feature test: the deleted routes return 404 / are unregistered.
* Feature test: N+1 rapid `verify-otp` calls return HTTP 429.
* Feature test: `forgot-password` response JSON has **no** `otp` key
  (this rewrites the test that currently pins the leak — rule 2).
* App test: after `totalDataClean()` the secure store has no token and
  a fresh Dio client carries no `Authorization` header.
* TLS-override removal has no clean unit test — assert the override
  class is gone and verify manually against a known-bad cert host;
  record that in the PR.

**Behaviour change:** yes (intended). **Risk:** medium — auth paths;
small surface each.

---

## EP2 — Security: uploads & remaining hardening

**Goal:** the rest of backlog §1 that is not "exploitable in one
request" but still security debt.

**Items:** `mimes:` + size caps on every upload rule and move uploads
out of web-served `public/` (use `storage/` or S3); restrict
`config/cors.php` origins; stop leaking `$e->getMessage()` to clients;
move the `backend.php` admin groups inside an explicit `auth`+`admin`
group; trim `User::$fillable` of security-sensitive columns; give
`FirebaseTokens` an explicit `$fillable`; `random_int()` for all OTPs;
gate `dio/log.dart` on `kDebugMode` and redact `Authorization` / OTP;
downgrade the `channels.php` PII logging; remove `test-s3` / diagnostic
routes; `0755` upload dirs; `SESSION_SECURE_COOKIE`.

**Test environment:** existing. Backend Feature tests use
`Storage::fake()` for upload assertions.

**Tests written first:** Feature tests rejecting `.php` / `.svg`
uploads and oversize files; a test that an exception response body
contains a generic message, not a stack trace; a test that admin
settings routes 401/403 without auth.

**Behaviour change:** yes. **Risk:** medium.

---

## EP3 — Correctness bugs (HIGH), excluding the patent flow

**Goal:** the §3 HIGH bugs that are wrong-but-not-patent.

**Items:** fix `SingleChatController::typingStatus` event reference;
resolve social login (**DG2** — wire up or delete); remove the
`dd("jalis")` in `Helper::deleteImage`; fix `ProfileController` writing
a non-existent `name` column; implement or remove the 5 missing
`AdminGroupChatController` methods; add `hasError` branches to the
feature-screen `StreamBuilder`s.

**Test environment:** existing. The `StreamBuilder` error-state work
uses `pumpInApp`.

**Tests written first:** Feature test that `POST /v2/auth/chat/typing`
returns 200 and broadcasts; Feature test for profile update actually
persisting `first_name`/`last_name`; widget test that a feature screen
shows an error+retry state when its stream errors.

**Behaviour change:** yes. **Risk:** medium.

---

## EP4 — Patent-flow hardening

**Goal:** fix the patent-path correctness bugs without breaking the
patented behaviour. Treated as its own phase because of its risk.

**Test environment — NEW, build first:** an `InboxScreen` /
`GroupInboxScreen` integration harness — inject fake Pusher events,
reuse the `ReactionRecorder` global-swap to fake the camera, fake the
`rx_*` singletons, drive the full loop: tap placeholder → `mark-viewed`
→ record → upload → optimistic insert → reconcile. **This harness PR
lands in CI green before any patent-flow code changes** (backlog §10
calls out that this integration test is missing and `CLAUDE.md`
mandates it).

**Items (after the harness is in):** collapse the duplicated
`_buildBlurPlaceholder` branches into one path; handle the
`mark-viewed`-failed case (retryable placeholder + error surface);
handle `recordVideoSilently()` returning `null` (telemetry, no silent
no-op); check camera/mic permission before recording; guard the
force-unwrapped `messageId!`/`userId!`/`groupId!`.

**Decision gate DG1:** the privacy consent UX / disclosure for the
silent recording needs product + legal. The engineering items above do
not wait on it; the consent flow itself does.

**Behaviour change:** failure paths only — the success path stays
identical. **Risk:** high — re-run all patent suites every PR.

---

## EP5 — Database & data model

**Goal:** backlog §4.

**Items:** add `SoftDeletes` to `User` (and confirm the `whereNull`
filters then behave); add the missing indexes / drop the redundant
`chats` indexes; resolve `TypingIndicator` and the `notifications`
table (add migration or delete model — see EP11); fix the
`User`/`GroupMessage` cast & `$fillable` drift; drop the dead
`job_categories` / `c_m_s` schema; verify `Room` pair normalisation.

**Test environment:** existing — Feature tests with `RefreshDatabase`
exercise migrations and model behaviour.

**Tests written first:** test that a soft-deleted user is excluded from
chat/friend/search results; migration tests that the new indexes exist;
cast tests for the blur flags.

**Behaviour change:** yes (soft-delete visibility especially). **Risk:**
medium-high — `SoftDeletes` changes every default `User` query;
broad test coverage needed.

---

## EP6 — API design & robustness

**Goal:** backlog §5.

**Items:** real pagination on `ChatService::conversation` (kill
`$perPage = 100000`); standardise the response envelope and the 422
body; migrate inline validation to Form Requests; normalise the route
versioning/param scheme (**DG7** — confirm v2 is the keeper); add an
OpenAPI/Postman spec under `docs/`.

**Test environment:** existing. Envelope/pagination changes will break
many existing Feature tests — rewrite them in the same PRs (rule 2).

**Behaviour change:** yes — response shapes change; the client team
must be coordinated with. **Risk:** high — wide blast radius; do it as
many small PRs, one endpoint group at a time.

---

## EP7 — Backend architecture

**Goal:** backlog §6.

**Items:** retire the v1 chat controller once clients are on v2 (DG7);
decompose the large services into cohesive units; inject collaborators
into services (this is also **test-env work** — it unblocks true
no-boot service unit tests, so raise the coverage floor afterwards);
move `Chat`'s viewer-relative accessors into an API Resource; fix the
`allFriends()` N+1 and `Room::lastMessage()`; resolve Cashier (**DG6**).

**Test environment:** existing for Feature tests; DI work *creates* the
no-boot unit-test capability.

**Behaviour change:** mostly behaviour-preserving (it is a refactor on
top of the now-correct behaviour) — but gated by the EP5/EP6 tests.
**Risk:** medium.

---

## EP8 — App architecture

**Goal:** backlog §7.

**Items:** consolidate onto one state-management paradigm (GetX is
already the root) and move chat logic out of the `StatefulWidget`s into
controllers; add offline detection + an offline state; null-check the
token reads; scope the composer rebuild; fix `loading_helper`'s
dialog-pop bug; make `receiver_message_widget`'s `isBlurred` `final`;
sane Dio timeouts; remove the redundant `MediaQuery`/`PopScope`/3s
delay; remove debug logs.

**Test environment:** existing `pumpInApp`; the EP4 harness covers the
moved chat logic. Moving logic into controllers makes it unit-testable
— add those tests.

**Behaviour change:** mixed. **Risk:** medium-high — large surface;
many small PRs; EP4 harness guards the chat-critical parts.

---

## EP9 — Performance

**Goal:** backlog §8.

**Items:** queued jobs for Pusher/FCM fan-out and Mail; drop
`shrinkWrap: true` on the message lists; paginate notifications; prune
`_messageKeys` and clear/scope `VideoControllerCache`; review
`listCombined`'s per-user `firstOrCreate`; consider read-endpoint
caching.

**Test environment:** existing — `Queue::fake()` / `Mail::fake()` for
the backend; widget tests for the list changes.

**Behaviour change:** push/mail become async (observable timing
change). **Risk:** low-medium.

---

## EP10 — UX, accessibility & internationalization

**Goal:** backlog §9.

**Items:** decide the language story (**DG5**) and either commit to one
language + align `Accept-Language`, or add real `flutter_localizations`
/ ARB localization; add `Semantics` labels (especially the
blur-placeholder tap); proper empty/error states; move colour literals
into theme tokens and decide on light-mode support (**DG4**); plan the
Material 3 migration.

**Test environment:** existing `pumpInApp`; widget tests assert
semantics labels and empty/error states.

**Behaviour change:** yes (UX). **Risk:** low-medium.

---

## EP11 — Dead code deletion & repo hygiene

**Goal:** backlog §12 and §13. Can run incrementally alongside other
phases (delete a thing when its phase touches that area) or as a
cleanup pass at the end.

**Items:** delete the §13 dead-code list (orphaned services, template
notifications, dead CMS schema, the fully-commented
`video_view_screen.dart`, stray `File.txt`, unused dependencies);
resolve the committed Firebase config (**DG3**); add `LICENSE` /
`CONTRIBUTING.md` / `docs/architecture.md`; rewrite the template /
inaccurate READMEs; establish release tagging + `CHANGELOG.md`; finish
the `achiar_expert_app` → `reacti` rename; add build flavors; prune
stale remote branches.

**Test environment:** existing — deletions are proved by CI staying
green (nothing referenced the deleted code).

**Behaviour change:** none (deletions) / docs. **Risk:** low.

---

## Decision gates (need a non-engineering call)

| Gate | Decision needed | Blocks |
|---|---|---|
| **DG1** | Privacy consent UX / disclosure for the silent recording — *legal + product* | EP4 consent item only |
| **DG2** | Social login — wire it up or delete it | one EP3 item |
| **DG3** | Committed Firebase config — accept-as-public+document, or gitignore+templates | one EP11 item |
| **DG4** | Support a light theme, or commit to dark-only | one EP10 item |
| **DG5** | One hardcoded language (which?) vs real i18n | EP10 i18n item |
| **DG6** | Billing — finish the Cashier integration or remove it | one EP7 item |
| **DG7** | Confirm v2 chat API is the keeper + plan client migration off v1 | EP6 route work, EP7 v1 retirement |
| **DG8** | Obtain the original `composer.json` from the dev team | the `composer install` switch in EP0 |

## Suggested sequencing

EP0 → EP1 → EP2 → EP3 run in order (security and correctness first, each
small). EP4 starts once its harness PR is merged; it can overlap EP5.
EP5 → EP6 → EP7 are the backend structural spine and run in order
(EP6/EP7 depend on EP5's correct schema and the EP6 test rewrites).
EP8 can start after EP4. EP9, EP10, EP11 are lower-risk and can be
slotted in opportunistically. The decision gates should be raised with
the product owner now so they are answered before their phase arrives —
DG8 in particular blocks part of EP0.

A realistic checkpoint to stop and review with stakeholders is after
**EP3** (the app is materially safer and more correct, with no
wide-blast-radius API changes yet) and again after **EP6** (the API
contract has changed and the client team must be in sync).
