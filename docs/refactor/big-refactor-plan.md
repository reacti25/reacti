# Big refactor plan — conventions, structure, decomposition

This is the third and largest refactor — successor to the
behaviour-preserving CP1-6 (`backend-refactor-plan.md`) and FP1/FP2/FP5
(`frontend-refactor-plan.md`).

**Goal.** Adopt the best *existing* convention on each axis and apply it
uniformly across the codebase. Restructure files where the layout is
inconsistent. Decompose the parts that resist reading. Delete what
nobody uses. End state: a reader landing in any file finds the same
naming, the same formatting, the same response shape, the same
directory layout — and the things that read badly today read quickly.

This refactor is mostly **behaviour-preserving**; the explicitly
behaviour-changing phases (response-envelope unification, real
pagination, route renames clients depend on) are isolated to phase R7
and gated on a coordination decision with the mobile-client team.

---

## Decisions resolved (2026-05-20)

The four decision gates were partly resolved by the product owner:

- **DG-A → Defer R7 + R3a entirely.** No mobile-client envelope
  coordination this round. Execute only R0-R6 + R8 (the
  behaviour-preserving spine) and R10 (below).
- **DG-B → Package name `reacti_app`.** R6 renames to that, matching
  the Android `applicationId` `com.reacti.app`.
- **DG-C → Keep social login and wire it correctly.** Instead of
  deleting `SocialLoginController` + `SocialAuthService`, fix the
  broken wiring — added as new phase **R10**. The User model's
  `is_google_signin` / `google_id` columns stay.
- **DG-D** (Cashier finish-or-remove) — not addressed. Cashier stays
  in place for now; R2b does not sweep it.

In-scope for this refactor: **R0 → R1 → R2 → R3b → R4 → R5 → R6**
(safe path) **+ R8** (decomposition) **+ R10** (social login wire-up).
Out of scope: R3a, R7, R8e (client-breaking) and R9 (optional
long-tail).

---

## Conventions chosen

One rule per axis, drawn from the *dominant existing* pattern in this
repo (not invented). New code conforms; existing code converges through
the phases below.

### PHP / Laravel backend

| Axis | Rule | Why this one |
|---|---|---|
| Method naming | `camelCase` | ~95% of controllers/services already are. The Web-admin `UpdateProfile`/`UpdatePassword` PascalCase methods are the outliers. |
| Class naming | `UpperCamelCase` | Universal already. |
| File / namespace | One class per file, PSR-4 | Universal already. |
| Directory pluralisation | `App\Helpers` (plural) | `Services`, `Models`, `Controllers`, `Events`, `Notifications`, `Resources` are all plural. `App\Helper` (singular) is the lone outlier. |
| Route URLs | kebab-case | `mark-viewed`, `forgot-password`, `add-members` are the majority. |
| Route placeholders | camelCase (`{groupId}`) | Pick the camelCase form (already used in v2 chat). Current mix: `{group_id}` / `{groupId}` / `{user}` / `{id}`. |
| Validation | Form Requests in `App\Http\Requests\…` | Laravel idiom. Inline `Validator::make` is what blocks decomposing fat controllers. |
| Response envelope | `{ success, message, data, code }` | Drops the trait's `success`/`status` key asymmetry on error. *Behaviour change — gated on R7.* |
| HTTP status codes | Real codes (404 / 422 / 401 / 403 / 500) | Drops 200-with-`success:false` for soft failures (v2 already does this; v1 doesn't). |
| PHPDoc | one-line summary + `@param` / `@return` / `@throws` | Already mostly there; needs the stale "preserved verbatim" / "must not be fixed" / emoji notes swept. |
| Formatting | `vendor/bin/pint` (PSR-12 defaults) | Already the project's choice — just not gated in CI. |

### Dart / Flutter app

| Axis | Rule | Why |
|---|---|---|
| File names | `lower_snake_case.dart` | Universal already. |
| Class names | `UpperCamelCase` | Universal already. |
| Field / variable | `lowerCamelCase` | Universal already. |
| `StatefulWidget` config | `final` fields | The mutable public `isBlurred` on `ReceiverMessageWidget` is the lone exception (the `must_be_immutable` lint suppression flags it). |
| Package name | `reacti_app` | Matches the Android `applicationId` `com.reacti.app`. `achiar_expert_app` is a former-project residue. |
| Imports order | `dart:` → `package:` → relative | Effective Dart guidance. |
| Formatting | `dart format` | Already the project's choice — just not gated. |
| Spelling | English-correct | `ChnagePasswordApi`, `RECIEVE_TIMEOUT`, `resonseCode`, `avater`, `waitingForSucess`. |

### Repo / project

| Axis | Rule |
|---|---|
| Commits | Conventional Commits — already followed |
| Branches | `refactor/<scope>-<topic>` off `develop`; one concern per PR |
| Required checks | `PHP Tests` + `Analyze & Test` — both always report (already done) |
| Docs | `README.md` at root and each subproject; `CONTRIBUTING.md`, `LICENSE`, `CHANGELOG.md` |

---

## Operating rules

1. **Conventions doc lands first.** Phase R0 pins every rule above as
   `docs/conventions.md`, referenced from root `CLAUDE.md`. From then
   on it is the source of truth.
2. **Behaviour-preserving phases first** (R1-R6, R8, R9).
   Behaviour-changing phases (R3a, R7, R8e) wait on the decision gates.
3. **Mechanical sweeps get a dedicated PR.** Never combine a format
   pass with a logic change — the diff becomes unreviewable.
4. **CI green at every step.** Required checks pass on every PR.
5. **Mass renames are one PR.** A partial package-rename PR is a broken
   build. Big diff is acceptable; broken is not.

---

## Phases

### R0 — Conventions doc (1 PR, no code change)

Pin the picks above into `docs/conventions.md`. Reference from root
`CLAUDE.md`. Source of truth for every subsequent phase.

- **Risk:** none.
- **Diff size:** small.

### R1 — Mechanical format pass (2 PRs)

End state: `pint`-clean backend, `dart format`-clean app, both gated in
CI.

- **R1a** `chore(backend): pint .` + add the Pint job to
  `backend-ci.yml`. The existing CI comment explicitly sanctions this
  as a dedicated PR ("the agency code has 115 style issues across 187
  files").
- **R1b** `chore(app): dart format .` + add
  `dart format --set-exit-if-changed` to `flutter-ci.yml`. The CI
  comment similarly sanctions this.

- **Tests:** existing — they verify nothing semantic changed.
- **Risk:** low. Mechanical formatting; no logic touched.
- **Diff size:** very large (hundreds of files), but each line is
  whitespace / brace placement.

### R2 — Dead-code deletion (3 PRs)

Delete the §13 list from `code-quality-backlog.md`. Each deletion is
proved by CI staying green (nothing references the deleted code).

- **R2a (app)** `app/lib/.../video_view_screen.dart` (entire file
  commented out, ~170 lines), `app/ios/File.txt`,
  `flutter_displaymode` and `chewie` from `pubspec.yaml`, and the
  large commented-out blocks in `receiver_message_widget.dart`,
  `helpers_method.dart`, `api_access.dart`.
- **R2b (backend)** `App\Services\ChatFileService` (orphaned),
  `App\Notifications/*` (template leftovers — events/posts/follow
  domain doesn't exist here), `App\Models\TypingIndicator` (no
  migration), `App\Enums\PageEnum` + `SectionEnum` + the `c_m_s` and
  `job_categories` migrations + a "drop the dead tables" migration,
  `reverb` npm dependency.
- **R2c (backend)** The 4 unrouted Web\Backend controllers from
  `inventory.md` §8 and the `TermsAndPolicyController` stub.

- **Tests:** existing.
- **Risk:** low. The dead-table drop migration on production data is
  the only "watch out" — but those tables are demonstrably unused.
- **Diff size:** moderate (deletes only).

### R3 — Symbol misspelling sweep (2 PRs)

End state: no misspelled public symbols.

- **R3a (backend — DG-A gated)** `userDetais` → `userDetails`
  (controller method + route + every test). **Breaks mobile clients
  pinned to the old path** unless rolled out with a temporary
  alias-route or a coordinated mobile release. *Defers until DG-A
  decided.*
- **R3b (app — safe)** Rename via tooling + repo-wide find/replace:
  - `ChnagePasswordApi` → `ChangePasswordApi`
  - `RECIEVE_TIMEOUT` → `RECEIVE_TIMEOUT`
  - `Failure.resonseCode` → `responseCode`
  - `avater` (widget constructor param) → `avatar`
  - `waitingForSucess` / `waitingForSucessWithoutIndicator` →
    `waitingForSuccess` / `waitingForSuccessWithoutIndicator`

- **Tests:** existing; the analyzer + tests catch every missed call
  site.
- **Risk:** R3b low; R3a HIGH (client-breaking).
- **Diff size:** R3b touches ~40-60 files; R3a touches ~5.

### R4 — PHP method-case normalisation (1 PR)

End state: every controller method is `camelCase`.

- `Web\Backend\Settings\ProfileController` `UpdateProfile` →
  `updateProfile`, `UpdatePassword` → `updatePassword`,
  `UpdateProfilePicture` → `updateProfilePicture`.
- `routes/backend.php` closure refs updated.
- Tests updated.

- **Tests:** existing.
- **Risk:** low — these are internal/admin routes; the URLs are not
  pinned by the mobile client.
- **Diff size:** small (~6 files).

### R5 — File / directory renames (2 PRs)

End state: directory and file names match conventions.

- **R5a** `backend/app/Helper/Helper.php` →
  `backend/app/Helpers/Helper.php`. Namespace `App\Helper` →
  `App\Helpers`. Update every `use App\Helper\Helper;` (~40 files) and
  composer's PSR-4 mapping is automatic.
- **R5b** `app/lib/constants/custome_theme.dart` → `custom_theme.dart`.
  Update every importer.

- **Tests:** existing; both compilers catch every missed import.
- **Risk:** low.
- **Diff size:** R5a ~40 files; R5b a handful.

### R6 — Flutter package rename (1 large PR)

End state: the package is named `reacti_app`, matching the bundle.

- `pubspec.yaml` `name: reacti_app` (and self-refs).
- Every `import 'package:achiar_expert_app/...';` →
  `import 'package:reacti_app/...';` (~280 files).
- Android: move
  `app/android/app/src/main/kotlin/com/example/achiar_expert_app/MainActivity.kt`
  → `com/reacti/app/MainActivity.kt` (the bundle id is already
  `com.reacti.app`; the Kotlin source path was the residue).
- iOS bundle stays as-is (already correct).

- **Tests:** `flutter analyze` + the test suite + the Android build
  catch every missed import.
- **Risk:** medium. Big diff, single mechanical sed; cannot be split
  (partial rename = broken build).
- **Diff size:** very large (~280 files); ~95% one-line import edits.

### R7 — Response envelope + Form Requests + status codes ⚠ DG-A gated

End state: one envelope, all validation via Form Requests, real HTTP
status codes throughout.

- Standard envelope `{ success, message, data, code }` on every
  endpoint; drop the `error` key shape that uses `status` instead of
  `success`.
- `Validator::make` everywhere → `App\Http\Requests\…` per endpoint
  (or per controller).
- 200-with-`success:false` soft failures → real 404/422/401/403.

- **Tests:** the existing endpoint suite is the safety net — every
  test rewrites its envelope/status assertions in the same PR.
- **Risk:** **HIGH — breaks the mobile client.** Either coordinate
  with mobile (rollout window) or do it additively (new endpoints
  alongside the old; deprecate v1 once mobile is off).
- **Diff size:** large; one PR per controller is realistic (~10-15
  PRs).
- **Decision needed: DG-A.**

### R8 — Service decomposition + Eloquent polish (3-5 PRs)

End state: no service over ~400 lines; no N+1; query reuse via scopes;
viewer-relative fields resolved once per request.

- **R8a** `SingleChatService` (~1000 L) → focused sub-services by
  responsibility (read / send / mark-viewed / pagination).
- **R8b** `User::allFriends()` → query scope (no per-relation pluck).
- **R8c** `Room::lastMessage` → `latestOfMany`.
- **R8d** `Chat::$appends` viewer-relative accessors → `ChatResource`
  (API Resource); viewer resolved once per request.
- **R8e** `ChatService::conversation` real pagination (kill
  `$perPage = 100000`). *Behaviour change — DG-A gated.*

- **Tests:** existing endpoint coverage is the safety net.
  Service-level unit tests grow here.
- **Risk:** medium for R8a (large move); low for R8b-d; R8e
  client-breaking.
- **Diff size:** moderate per PR.

### R9 — DTOs / value objects (long-tail, optional)

End state: typed boundaries between controller ↔ service ↔ repo.

- Introduce `App\Data\` (or `App\DTOs\`).
- Replace raw associative arrays at the controller/service boundary.

- **Risk:** low; spread over many small PRs.
- **When:** opportunistic, after R8 settles.

### R10 — Social login wire-up (DG-C resolution)

End state: `POST /api/social/signin/{provider}` actually works.

Currently the route points at the non-existent
`SocialLoginController::socialSignin` (the real method is
`googleAuthentication`) AND `SocialAuthService::googleAuthenticate`
writes `name` + `is_otp_verified` columns that aren't on the `users`
table. Either fact alone makes the flow throw on first call.

Work:

- Point the route at the real method (`googleAuthentication`) or
  rename the method to match — pick one consistently with the chosen
  convention (R4).
- Constrain the `{provider}` route param to `in:google,apple`.
- Fix the column writes — use `first_name`/`last_name` and
  `otp_verified_at` (and the existing `is_google_signin`/`google_id`).
- Tests for the happy path, the duplicate-account merge, and the
  unknown-provider rejection.

- **Risk:** medium. Touches auth code; needs careful test coverage.
- **Diff size:** small-to-moderate.

---

## Decision gates

| Gate | Question | Blocks |
|---|---|---|
| **DG-A** | Mobile client envelope coordination — coordinate, do additively, or defer? | R3a, R7 (all), R8e |
| **DG-B** | Package rename target: `reacti_app` (recommended — matches bundle) or `reacti` | R6 |
| **DG-C** | Social login keep or kill (carries `App\Services\SocialAuthService`, `SocialLoginController`, the dead `googleAuthentication` method) | R2b scope |
| **DG-D** | Billing/Cashier finish or remove | R2b can sweep more |

---

## Sequencing

Safe path that needs no decision (R0 → R2 → R3b → R4 → R5 → R6):
**R0 → R1a → R1b → R2a → R2b → R2c → R3b → R4 → R5a → R5b → R6.**

That's ~13 PRs of conventions + format + delete + rename. The codebase
ends consistent in naming, structure, and formatting, with the dead
weight gone.

Decision-gated phases (R3a, R7, R8e) wait. R8a-d can run in parallel
with the safe path once R1 has settled (so format edits don't collide).

R9 is opportunistic.

---

## What this refactor is NOT

- Patent-flow rework — that's EP4 in `docs/enhancement-plan.md`.
- New features or new behaviour.
- Database-schema changes (`SoftDeletes`, indexes) — EP5 territory.
- The `flutter_secure_storage` migration — deferred from EP1.
- A re-write of any well-isolated subsystem.

---

## Estimate

Roughly 30-50 PRs over ~2 working weeks if executed end-to-end. The
mechanical phases (R1, R5, R6) each land in a day if mass-edits can
run uninterrupted. The decomposition phase (R8) and the
client-coordinated R7 take the bulk of the time.

A reasonable stop-and-review checkpoint is **after R6** — the codebase
is fully convention-consistent and structurally tidy at that point,
without having touched a single response shape. Most of the visible
"looks better, easier to read" win is at the R6 checkpoint.
