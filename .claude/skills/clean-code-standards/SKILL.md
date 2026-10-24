---
name: clean-code-standards
description: The standing operating manual for all work in the Reacti monorepo (Laravel/PHP backend in backend/, Flutter/Dart app in app/). Load this whenever writing, editing, refactoring, reviewing, or generating code in either codebase, AND whenever doing anything that touches branches, releases, deploys, CI, secrets, the patented silent-recording flow, or a product/legal decision. It carries two things: (1) the non-negotiable code-quality bar — docs on every function/class/file, why-comments, small single-purpose functions, unit tests wired into the required CI checks, OOP only where it earns its keep; and (2) the hard-won operational playbook learned from a real production incident — app-first release ordering, the prod-is-not-main promotion model, decision-gate parking, audit-before-you-act, secrets hygiene, and the specific CI/GitHub/Hostinger traps that have bitten this repo. Trigger it even for "quick" snippets, throwaway scripts, or "just a small change" — those are exactly where standards slip and PRs get blocked, and where an innocent-looking change has broken the live App Store app before. When in doubt, load it.
---

# Reacti — clean code & safe operations

This is the standing manual for the Reacti repo. Part 1 is the **code-quality
bar** (how every piece of code must look). Part 2 is the **operational
playbook** (how to branch, test, release, and deploy without breaking the live
app). Both are non-negotiable defaults; explicit, justified deviations are fine
and should be called out to Achia.

> Companion docs (read when relevant):
> `docs/conventions.md` (exact naming/layout/style), `CLAUDE.md` (entry point),
> `PROGRESS.md` (live status), `NEEDS-ACHIA.md` (open decision gates),
> `docs/handoffs/` (incident history — provenance, not live instructions),
> `docs/analytics/perf-workflow.md` (how to measure→locate→fix→re-measure
> performance from the analytics metrics — staging-first; run
> `scripts/analytics/perf_digest.py`).

## The two codebases at a glance

- **Backend** — Laravel 11 / PHP 8.2+, in `backend/`. Tests in
  `backend/tests/{Unit,Feature,Contract}/`, declared in `backend/phpunit.xml`,
  run with `php artisan test --ansi --display-warnings --coverage-clover=coverage/clover.xml`.
  CI: `.github/workflows/backend-ci.yml`, required check **"PHP Tests"**.
- **App** — Flutter / Dart, in `app/`. Tests in `app/test/` mirroring `lib/`,
  run with `flutter test --reporter expanded --coverage`. CI:
  `.github/workflows/flutter-ci.yml`, required check **"Analyze & Test"**.

Both **"PHP Tests"** and **"Analyze & Test"** are required to merge into
`develop` or `main`, and both always report on every PR (no `paths:` filter —
see the CI trap in Part 2). If a change touches either side, it ships with tests
that keep those checks green.

---

# Part 1 — Code-quality bar

Before writing code, walk the checklist at the end of Part 1 in your head.
After writing, walk it again and fix what slipped.

## 1. Document everything

Every function, method, class, and file gets a doc comment covering **what** it
does (one-line summary first), **why** it exists if not obvious, **params**
(name, type, meaning, allowed values), **returns**, **throws/errors**, and a
short **example** for anything non-trivial.

**PHP (`backend/`)** — PHPDoc blocks:

```php
/**
 * Charge the given user for an order and return the transaction id.
 *
 * Idempotent on $order->id — calling twice with the same order returns
 * the same transaction without double-charging.
 *
 * @param  User   $user
 * @param  Order  $order
 * @return string Transaction id from the payment provider.
 *
 * @throws PaymentDeclinedException When the provider returns a declined status.
 */
public function chargeOrder(User $user, Order $order): string
```

Type-hint every parameter and return; use property type declarations. The
language types are the source of truth; PHPDoc adds the *narrative*. Skip
`@return void`. Don't ship refactor-era residue ("preserved verbatim", emoji
notes).

**Dart (`app/`)** — `///` DartDoc above every public element:

```dart
/// Fetches the user's upcoming bookings, sorted by start time ascending.
///
/// Returns an empty list if the user has no bookings. Throws
/// [ApiException] if the network call fails after retries.
Future<List<Booking>> fetchUpcomingBookings(String userId) async { ... }
```

Reference symbols with `[BracketSyntax]`. Private members get a (shorter) doc
too. "It's obvious" is not an excuse.

## 2. Comment the *why*, not the *what*

Inline comments explain reasoning, edge cases, gotchas, workarounds for
framework quirks, performance choices, business constraints, and links to
tickets — never restate the next line.

```php
// Skip the header row; CSV import includes column names as the first record.
$i++;
```

Don't narrate self-explanatory code; over-commenting is its own noise.

## 3. Small, single-purpose functions

One thing per function. If the name needs an "and", it's two functions.

- ~20–30 lines of real code; one level of abstraction per function.
- ~3–4 parameters max; beyond that, group into a DTO / value object.
- No boolean flag parameters that split the body into two behaviours — split
  into two functions.

**Backend:** thin controllers — validate (Form Requests), delegate to a
service / action, return a response. Business logic lives in `app/Services/`,
`app/Actions/`, domain classes. Models hold relationships and scopes, not
multi-step workflows.

**App:** short `build()` methods; extract sub-widgets into their own classes.
Logic lives in the existing state layer (GetX controllers, `rx_*` data sources,
`get_it` DI) — match the established pattern, don't introduce a second one
without asking.

## 4. Unit tests, wired into CI

No code is done until it has tests, and they run on every push/PR. For each new
or changed function/method/class/widget, cover the happy path, the obvious edges
(empty, boundary, null), and the error paths. One behaviour per test; names read
as sentences; tests are deterministic (no real network/clock/filesystem unless
that is the point — fake them).

**Backend — `backend/tests/`**

- `Unit/` — pure logic, no framework boot, no DB.
- `Feature/` — boots the app, hits routes/jobs/commands end-to-end. Use
  `RefreshDatabase`; fake with `Http::fake()`, `Queue::fake()`, `Event::fake()`,
  `Storage::fake()`, `Mail::fake()`.
- `Contract/` — **API-shape contract tests.** These exist because an
  API-shape divergence is what broke production (see Part 2). When you change
  any endpoint's response shape, update/extend the contract test for it.
- Put files inside the directories `backend/phpunit.xml` already maps. Don't add
  a new top-level test dir without updating `phpunit.xml` *and* the workflow.
- Naming: `Foo/BarTest.php`, `class BarTest extends TestCase`,
  `test_does_the_thing_when_condition`.

**App — `app/test/`**

- Mirror `lib/` (`lib/services/foo.dart` → `test/services/foo_test.dart`).
- `package:flutter_test` for widgets, `package:test` for pure Dart. The app has
  **no mocking package** — tests use hand-written fakes (a class that
  `implements`/extends the real type, or `extends Fake`). Match that; don't pull
  in `mockito`/`mocktail` without asking. (Backend has Mockery available, but
  prefer Laravel's built-in `*::fake()` helpers and `RefreshDatabase`.)
- Widget tests: pump inside `MaterialApp`; find by key/semantics/type over raw
  text; put `Key`s on test-critical elements.

**CI wiring — never break the required checks**

- `backend-ci.yml` → **"PHP Tests"**; `flutter-ci.yml` → **"Analyze & Test"**.
  Tests under the standard dirs run automatically.
- Never disable, `skip:`, `markTestSkipped`, or `continue-on-error: true` a
  required check to make a PR mergeable. If tests fail, fix them or report the
  failure honestly.
- Need a new CI step? Edit the matching `*-ci.yml` in the same PR and call it
  out. `deploy-dashboard.yml` is a deploy workflow — don't move tests into it.
- Coverage floors are enforced and ratcheted (backend `--min`, app line %).
  Raise them when you can; never lower them to pass.
- The **Dependency Audit** job is intentionally **RED** (deferred
  CVE-2026-48019; needs a major Laravel upgrade, tracked as its own project).
  Don't "fix" CI by silencing it; don't treat its red as a blocker.

## 5. Use OOP where it fits — and only where it fits

Reach for classes when you have **state + behaviour on that state**, or need
polymorphism. Good fits: Eloquent models, Form Requests, Policies, Services,
Actions, DTOs, Jobs, Events, Listeners, Mailables, Casts (backend); models,
repositories, services, GetX controllers, stateful widgets, value objects (app).
Match the framework — Laravel resolves these as classes.

Don't force it: a pure transformation is a function/static method; a
"Manager/Helper/Utils" bag of statics is a module in disguise (a `final` class
of statics in PHP, a top-level library function in Dart). One class per file;
composition over inheritance; private fields, behaviour via methods; in Dart
prefer `final` fields and `const` constructors.

## 6. Ponytail pass before every merge

Before any branch merges to `develop`, run a **ponytail inspection over that
branch's diff** — not the whole repo, just what the branch changed. Apply the
lazy-code ladder to your own new code: does this need to exist at all (YAGNI)?
does stdlib / a native feature / an already-installed dependency already do it?
can it be fewer lines? Delete dead/duplicate code you introduced, collapse
speculative abstractions (interface with one impl, config for a constant,
`Manager/Helper/Utils` bags of statics), and keep the shortest thing that works.

This is the standing inspection (the campaign in
`docs/PLAN-ponytail-refactor-2026-06-17.md` is the *codebase-wide* version; this
is the *per-branch* version). It must not change behaviour — tests stay green.
If a deliberate simplification has a known ceiling, leave a `ponytail:` comment
naming it. Run `/ponytail-review` on the diff if available.

## Pre-handoff checklist (Part 1)

Every answer must be "yes" before you call code done:

- Every function/method/class/file has a doc block (purpose, params, returns, errors).
- Non-obvious lines have a *why* comment.
- No function does more than one thing; flag-branching is split out.
- Ran a **ponytail pass over the branch diff before merge** (§6): no dead/duplicate
  code, no speculative abstractions, simplest rung that works; behaviour unchanged.
- Backend controllers are thin; app widgets are thin; logic sits in the right layer.
- New/changed code has tests covering happy path, edges, and errors.
- PHP tests under `tests/{Unit,Feature,Contract}`; Flutter tests mirror `lib/`.
- Response-shape changes have an updated **Contract** test.
- `php artisan test ...` passes locally (backend); `flutter test` + `flutter analyze` pass locally (app).
- Required checks **"PHP Tests"** and **"Analyze & Test"** will run and aren't being skipped/disabled.
- Classes used where they earn their keep; clean naming (verbs for functions, nouns for classes).
- `vendor/bin/pint` (PHP) / `dart format .` (Dart) run clean.

---

# Part 2 — Operational playbook

This half exists because process mistakes here have **broken the live App Store
app** and **destroyed a rollback snapshot**. Treat it as load-bearing.

## The North-Star feature — do not regress

The patent-protected flow is *automatic, silent front-camera recording when a
recipient opens a media message*. Trigger:
`app/lib/.../chat/presentation/widget/receiver_message_widget.dart` →
`recordVideoSilently()`, called from `_buildBlurPlaceholder()` after a
successful `mark-viewed` call; the result uploads as a `type:"reaction"` message
(`sendMessageRx` / `sendGroupMessageRx`). Backend: `POST
/auth/chat/mark-viewed/{id}`, the send endpoints, Pusher broadcasts.

If you touch the blur/unblur transition, the recording trigger, the reaction
upload path, `mark-viewed`, or the broadcast events — **write/update an
end-to-end regression test that exercises the full loop** (the patent-flow
harness already covers InboxScreen and GroupInboxScreen; keep it green). A
behaviour-preserving change on this path still warrants a fresh staging
TestFlight build so Achia can confirm on-device.

## Golden rule — app and backend move together, **app first**

A backend deploy to production once **broke the live app** and had to be rolled
back. Root cause: the App Store app is the **OLD** app; deploying the new
backend changed response shapes the old app couldn't read (`is_viewed`
int-vs-bool) → black chat screen. Staging was fine because the staging app is
the NEW app.

Therefore:

1. **Release the new iOS app to the App Store first** and let it adopt.
2. **Then** the operator approves the production Backend Deploy gate.
3. Merging `develop`→`main` is fine anytime (code only). The **production
   backend deploy gate stays UNAPPROVED until the new app is live.**

This is why API-shape changes are dangerous and why **Contract tests** exist.
Never assume the live client matches `main`.

## Branch & promotion model — prod ≠ main

- `develop` is the integration branch; everything lands there as small,
  single-concern, self-reviewed PRs (Conventional Commits, squash-merge).
- **develop must be releasable at all times.** It is the only road to prod,
  so anything parked on it blocks every release behind it. Work that waits on
  a soak, a cutover, an outside party or a later phase (an infra migration,
  a half-built feature) lives on its **own long-lived branch** and merges into
  develop only when it is ready to ship. Choosing develop for an initiative
  is a **decision gate**: ask Achia in plain words before the first merge.
  (2026-10-21: AWS Phase 1 was merged into develop because the plan said so;
  it needed a week's soak and blocked the insights release. Reverted in #507.)
- **Merge gate:** `.claude/hooks/merge_gate.py` refuses `gh pr merge` until
  the PR description ticks "Ponytail pass" and "Releasable" (the Gate section
  of the PR template). Never bypass it.
- `main` is the release branch. `develop`→`main` is the promotion gate.
- **"Production runs `main`" is an aspiration, not always a fact.** Production
  has at times run a `develop` commit from incident recovery, with `develop`
  100+ commits ahead of `main`. Before reasoning about "what's in production",
  check what actually shipped — don't assume.
- Tag releases on `main` (`v1.2.3`); update `CHANGELOG.md`.

## Release cadence — run continuously, stop at a milestone

Don't stop after every step. Keep flowing on `develop`/staging. Maintain the
**"Next release — what's in it"** plain-language list in `PROGRESS.md` (every
user-facing change + security fix since the last release).

**Stop and signal a `RELEASE MILESTONE`** only when the batch is worth
shipping to real users — user-meaningful improvements, not pure CI/refactor/docs
work. At a milestone: write the entry in `PROGRESS.md`, confirm green on
staging, and tell Achia it's time for an App-Store release (app first), then the
operator deploys the backend. **You do not run the release** — tagging/releasing
the app and approving the backend deploy are Achia + operator steps.

## Decision gates — park, don't block

Product, legal, or business calls are **Achia's**, not yours. When you hit one:
record it in `NEEDS-ACHIA.md`, keep working on everything else, and **never**
promote to `main`, deploy to prod, or touch the App Store to force it. Examples
that are gated: the silent-recording **consent/disclosure UX** (a release
blocker for that feature — legal wording is the lawyer's), billing
removal, language/theme scope. When a gate is resolved, implement it and mark it
resolved in `NEEDS-ACHIA.md`.

## Audit before you act — premises go stale

Repeatedly, "known" facts turned out wrong: items thought unfixed were already
fixed and pinned by tests; "dead" social-login code was actually wired up,
working, and tested. **Verify the current state of the code before you delete,
rewrite, or act on a stale premise** — and never delete working, tested code on
an "it's dead" assumption without re-confirming with Achia. When the plan and
reality disagree, flag it; don't silently follow the stale plan.

## Secrets hygiene — Achia is non-technical

- **Never ask Achia to paste secrets, passwords, or private keys into chat**, or
  to screenshot a file containing them. If she must share a file, ask her to
  grep out only the non-secret lines first.
- Public keys are fine in chat. **Private keys go via `gh secret set` from the
  workspace and are never displayed.**
- Never commit anything under `.local-secrets/`, a real `.env` (only
  `.env.example`), or any `*.json` holding a service-account key — these are
  gitignored; keep it that way. `archives/` (the delivery zips/rars) is
  gitignored on purpose: keep it local, never commit it.
- Never weaken TLS (`MyHttpOverrides`, `verify=False`, `--insecure`) without an
  explicit, time-boxed reason in the PR description. (`app/lib/main.dart`'s TLS
  override is already on the cleanup list — don't extend it.)

## GitHub & CI traps that have bitten this repo

- **Path filters + required checks = deadlock.** A required check with a
  `paths:` filter never runs for a PR that doesn't touch that path, so the PR
  can never satisfy it. Keep `backend-ci.yml` / `flutter-ci.yml` filter-free so
  they always report.
- **There are TWO branch-protection systems** — classic *Branch protection
  rules* and *Rulesets*. Both enforce independently. When "why won't this PR
  merge?", check both. If you ever disable a ruleset to land something,
  re-enable it immediately.
- When grafting a workflow onto `main`, pull **only** the one file you need
  (`git checkout origin/develop -- path/to.yml`) — don't drag in supporting
  files that don't exist on `main` and create a broken half-workflow.

## Hostinger / production server — operator's lane

- **Do not run any production deploy or open CI→prod SSH connections** unless
  explicitly told. A burst of GitHub-runner SSH attempts tripped Hostinger's
  edge abuse-protection and **rate-blocked the runner IP range**; every extra
  attempt re-extends the block. Leave the prod server alone.
- **Hostinger keeps only one VPS snapshot slot.** Creating a new snapshot
  **overwrites** the previous one — taking a "broken state" snapshot once
  destroyed the pre-deploy rollback point. Never snapshot over your rollback.
- Staging deploys from `develop` (to `staging.reacti.io`, a sealed sandbox DB)
  are fine and expected.

## Staging & smoke testing

Staging is the **NEW** app on TestFlight ("Reacti Staging", amber icon,
`com.reacti.app.staging`), pointed at `https://staging.reacti.io/api`. Seeded
test accounts: `smoke-a@reacti.test` (owner) and `smoke-b@reacti.test` (member),
friends sharing "Smoke Test Group". The shared password lives offline (env
`STAGING_SEED_PASSWORD`), never in the repo. Run locally against staging with
`flutter run --dart-define=BASE_URL=https://staging.reacti.io/api --dart-define=APP_KEY_VALUE=staging-testflight`.

## Open carry-overs to be aware of

- **DG8** — the original `composer.json` from the dev team hasn't arrived;
  `backend/composer.json` was reconstructed from `composer.lock`, so CI stays on
  `composer update` (not `install`) until the original lands.
- The deferred **CVE-2026-48019** (red Dependency Audit) is its own future
  project, not routine work.

## When a rule conflicts with reality

Legacy files, vendored code, one-off migrations, and generated files have their
o