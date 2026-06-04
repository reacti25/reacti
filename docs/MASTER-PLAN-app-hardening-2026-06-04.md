# Reacti — Master Plan: make it solid, then grow it

**Date:** 2026-06-04
**Owner:** Achia (non-developer; works with Claude Code)
**Purpose:** one ordered roadmap to take Reacti from "works, but fragile" to
"well-tested, well-documented, clean, fast" — and only *then* add features.

This plan does **not** reinvent the existing planning docs. It **sequences**
them into the order you asked for:

> tests for everything → docstrings for everything → safe refactor →
> refactor that changes behaviour → then new features.

It points at the detailed docs for each step:

- `docs/code-quality-backlog.md` — every known problem, by severity.
- `docs/enhancement-plan.md` — the behaviour-changing work as test-first phases (EP0–EP11) + decision gates (DG1–DG8).
- `docs/refactor/*-refactor-plan.md` — the safe refactor that is already done.
- `docs/PLAN-staging-and-testing-2026-05-24.md` — the staging + CI wall.
- `docs/testing/inventory.md` + `docs/testing/HOW-TO.md` — what's tested, how to test.
- `docs/conventions.md` — code style + commit rules.

---

## The five rules that hold for every stage

1. **Nothing reaches the real app without passing the wall.** Change lands on
   `develop` → verified by tests + by you on your iPhone via TestFlight →
   promoted to `main` → deployed. This is the existing North Star; keep it.
2. **Test-first.** The test that proves a change goes green in CI **before**
   the change is made. If a change needs new test machinery, that machinery is
   its own PR first.
3. **Pin-then-update.** Today's tests pin today's behaviour — including bugs.
   When you fix a bug, the old test (which asserted the bug) must be rewritten
   to assert the *correct* behaviour **in the same PR** — never deleted/skipped.
4. **One concern per PR.** Small, reviewable changes. A "phase" is many PRs.
5. **The patent flow is load-bearing.** Any change near `send` / `mark-viewed`
   / the blur flags / `recordVideoSilently` re-runs the patent test suites.
   See root `CLAUDE.md`.

---

## Where things stand today (honest snapshot)

- **Safe refactor: largely DONE.** R0–R10 (plus the earlier CP1–6 and FP1/2/5)
  already normalised style, removed dead code, split the giant chat service,
  fixed naming, and wired CI format gates. So **your "stage 3" is mostly
  already complete** — we only mop up leftovers, not redo it.
- **Tests: substantial but uneven.** ~80 Flutter test files and ~55 backend
  test files exist (auth, friends, groups, moderation, the patent reaction
  flow, contract tests). But coverage is patchy: no full-screen integration
  test for the patent flow, services/screens under-covered, no coverage floor.
- **Backlog: written, not yet fixed.** `code-quality-backlog.md` catalogues the
  problems — including security holes that are **exploitable today**.
- **Staging + CI wall: in place.** `develop`→staging auto-deploys; required
  checks gate `main`.

So the real ordering, adjusted for what's already done, is:
**finish the test net → document everything → (safe refactor already done) →
behaviour-changing hardening → features.**

---

## Stage 0 — Foundation: CI gates + test machinery  *(do first, low risk)*

Before mass-testing, make the gates real so coverage can't regress. This is
**EP0** in `enhancement-plan.md`. No app behaviour changes.

- Make **both** required checks always report (no-op job on the filtered path)
  so branch protection stops needing admin-merges.
- Add **PHPStan/Larastan** to backend CI with a baseline (fails only on *new*
  issues).
- Enforce `dart format` + stricter `flutter analyze` in app CI.
- Re-enable a **native build** job (`flutter build apk --debug`) so compile
  breaks are caught; track the iOS-build gap as a ticket.
- Add **coverage reporting** to both pipelines (no threshold yet).
- Add `composer audit` + **Dependabot** (composer / pub / npm / actions).
- Point the dashboard workflow at `develop`.

**Done when:** the workflows themselves go green with the new gates on.

---

## Stage 1 — Test net: pin current behaviour everywhere  *("test for anything")*

Goal: a **safety net** so later changes can't silently break things. We write
**characterization tests** — they lock in how the app behaves *now* (bugs
included; those get corrected later under rule 3). Priorities:

- **Patent-flow integration harness (highest value, currently missing).** A
  full `InboxScreen` / `GroupInboxScreen` test that drives the whole loop: tap
  placeholder → `mark-viewed` → record (fake camera) → upload → optimistic
  insert → reconcile (fake Pusher). `CLAUDE.md` mandates this; it's also the
  prerequisite for safely touching the patent code in Stage 4d. *(This is the
  harness EP4 builds — pull it forward to here.)*
- **Backend service unit tests** for the extracted `app/Services/*` (now that
  logic lives there).
- **Backend feature tests** for the ~80 routes that are mostly untested
  (groups, moderation, profile, firebase tokens, events/broadcasts).
- **App `rx_*` data-source tests** and **screen widget tests** (login/signup/
  OTP, inbox, group inbox) via the existing `pumpInApp` harness.
- **Set a coverage floor** once the net is broad, and **ratchet it up** each
  later stage so coverage only ever rises.

**Reality check on "test everything first":** we don't need 100% before any
change — we need a *trustworthy net around the risky areas* (patent flow, auth,
chat, money-/data-loss paths). Aim for those first; fill the long tail
opportunistically as later stages touch each area.

**Done when:** the patent harness is green in CI, the risky paths are covered,
and a coverage floor is enforced.

---

## Stage 2 — Documentation: docstrings + architecture  *("doc string for everything")*

Goal: anyone (you, Claude Code, a future hire) can understand any file fast.

- **Dartdoc on every public class / method / widget** in `app/lib` (`///`
  comments): what it does, params, return, side-effects — especially the
  patent path, the `rx_*` registry, and the networking layer.
- **PHPDoc on every controller / service / model / event** in `backend/app`:
  purpose, params, thrown exceptions, the response envelope it returns.
- **`docs/architecture.md`** — the data model, the broadcast channels, and the
  reaction-message lifecycle end to end (backlog §12 asks for this).
- **API spec** — an OpenAPI/Postman collection under `docs/` so the client team
  has a real contract (backlog §5).
- Rewrite the **template/inaccurate READMEs** and add `CONTRIBUTING.md` +
  a proprietary `LICENSE` (backlog §12).
- Add a **doc-coverage check** to CI if practical (e.g. fail on undocumented
  public APIs) so docs don't rot.

This stage changes **no behaviour** — pure documentation — so it's low risk and
can overlap Stage 1.

---

## Stage 3 — Safe refactor (behaviour-preserving)  *— MOSTLY DONE ✅*

R0–R10 / CP1–6 / FP1/FP2/FP5 already did the heavy lifting (style, dead-code
removal, service split, renames, format gates). **Don't redo this.** Remaining
mop-up only, and only the parts that are still strictly behaviour-preserving:

- Finish the `achiar_expert_app` → `reacti` package/path rename (backlog §12).
- Delete the safe dead-code/files list that nothing references (backlog §13)
  — proved safe by CI staying green.
- Prune unused dependencies flagged by `dependency_validator` (backlog §11).

Anything that *changes behaviour* (e.g. swapping a storage disk, retiring v1
chat) is **not** here — it lives in Stage 4.

---

## Stage 4 — Functional hardening (behaviour changes), in priority order

This is `enhancement-plan.md` (EP1–EP11). Each sub-stage is several small,
test-first PRs. Ordered by danger-to-users first.

**4a — Security criticals, exploitable *today* (EP1). Highest priority.**
- Delete the unauthenticated `routes/web.php` maintenance routes (`/run-migrate-fresh`
  can **drop your whole database** — anyone with the URL). *Do this very early.*
- Add rate-limiting to all auth/OTP routes (the 4-digit OTP is brute-forceable
  in seconds today).
- Stop returning OTP codes in API responses (currently → trivial account
  takeover).
- Remove the app-wide TLS-validation bypass (`MyHttpOverrides`) — every API
  call is MITM-able right now.
- Move the auth token to secure storage and actually erase it on logout.

**4b — Security hardening (EP2):** upload `mimes:`/size limits + move uploads
out of the web root; lock down CORS; stop leaking exception details; tighten
admin route grouping; trim mass-assignable columns; redact tokens/OTP from
logs; remove diagnostic routes; secure session cookie.

**4c — Correctness bugs, non-patent (EP3):** fix the typing-event 500; resolve
social login (DG2); remove the stray `dd("jalis")`; fix profile-update writing
a non-existent column; implement/remove the 5 missing admin-group methods; add
error states to the screens that currently show a blank page on failure.

**4d — Patent-flow hardening (EP4).** *Requires the Stage 1 harness first.*
Collapse the duplicated blur-placeholder branches into one path; handle the
`mark-viewed`-failed and recording-failed cases (today they silently do
nothing); check camera/mic permission; guard the force-unwrapped ids. **Success
path stays identical; re-run all patent suites every PR.** The *consent UX* for
the silent recording is **DG1** — legal + product, a release blocker.

**4e — Data model (EP5):** add `SoftDeletes` to `User` (deleted users currently
still appear in chats/search); add missing indexes / drop redundant ones; fix
model cast & `$fillable` drift; resolve the model-without-a-table cases; drop
dead CMS schema.

**4f — API design (EP6):** real pagination on the conversation query (it fetches
the *entire* chat unpaginated today); standardise the response envelope + 422
shape; move validation to Form Requests; settle URL versioning (DG7); ship the
API spec. *Coordinate with the client team — response shapes change.*

**4g — Backend architecture (EP7):** retire the duplicate v1 chat controller
(DG7); decompose the large services; inject collaborators (unlocks fast unit
tests); move viewer-relative fields into API Resources; fix the N+1s; resolve
Cashier (DG6).

**4h — App architecture (EP8):** consolidate onto one state-management approach
(GetX is already the root) and move chat logic out of the widgets; add offline
detection; null-check token reads; fix the rebuild-on-every-keystroke and the
dialog-pop bug; sane network timeouts.

**4i — Performance (EP9):** queue the push/email fan-out; fix the message-list
lazy-building; paginate notifications; bound the video-controller cache.

**4j — UX / accessibility / i18n (EP10):** decide the language story (DG5);
add accessibility labels (especially on the recording placeholder); proper
empty/error states; theme tokens + light-mode decision (DG4); Material 3 plan.

**4k — Dead code & repo hygiene (EP11):** finish deletions; resolve committed
Firebase config (DG3); release tagging + `CHANGELOG.md`; build flavors; prune
stale branches.

**Checkpoints to stop and review with you:** after **4c** (app is materially
safer and more correct, no wide API changes yet) and after **4f** (API contract
changed — client team must be synced).

---

## Stage 5 — New features & app changes  *(only after Stage 4)*

Once the app is well-tested, documented, secure, correct, and clean, new
features become safe and fast to add. Each feature follows the same loop:
spec → tests first on `develop` → build → verify on staging + your iPhone →
promote to `main` → deploy to the real app. Feature ideas live in
`docs/vision/` and can be prioritised then.

---

## Decision gates — your input needed (raise these early)

These are product/legal/business calls, not engineering. They block specific
items; flag them now so they're answered before their stage arrives.

| Gate | Decision | Blocks |
|---|---|---|
| **DG1** | Consent UX / disclosure for the silent recording (legal + product) | 4d consent item — release blocker |
| **DG2** | Social login: wire it up or delete it | one 4c item |
| **DG3** | Committed Firebase config: accept-as-public+document, or gitignore+templates | one 4k item |
| **DG4** | Support light theme, or commit to dark-only | one 4j item |
| **DG5** | One hardcoded language (which?) vs real localisation | 4j i18n |
| **DG6** | Billing: finish Cashier or remove it | one 4g item |
| **DG7** | Confirm v2 chat API is the keeper + plan client migration off v1 | 4f / 4g |
| **DG8** | Obtain the original `composer.json` from the dev team | the `composer install` CI switch in Stage 0 |

---

## How this runs in practice (you + Claude Code)

- Each sub-stage = a handful of small PRs off `develop` (`test/*`,
  `docs/*`, `enhance/*`). Claude Code writes the test, makes the change,
  opens the PR.
- You review on **staging + TestFlight**, then approve the promotion to `main`.
- The **CRITICAL security items in 4a should be pulled forward** and done as
  soon as the Stage 0 gates exist — they're exploitable right now and shouldn't
  wait behind a full test sweep. (Each still gets its own test, per rule 2.)

## Suggested immediate next steps

1. Settle the current `develop`/`main` baseline question (the in-flight
   decision) so the branches are a stable starting line.
2. Do **Stage 0** (CI gates + coverage reporting + audit/Dependabot).
3. Pull forward **4a's** `routes/web.php` deletion and rate-limiting — highest
   real-world risk, small change each.
4. Build the **patent-flow integration harness** (Stage 1) — it unlocks safe
   work on the most important feature.
5. Answer **DG8** and **DG1** early (they gate the most).
