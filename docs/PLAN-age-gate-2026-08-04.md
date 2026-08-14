# PLAN — Signup age gate (2026-08-04)

## Why

Reacti has **no age check of any kind today**. Grep of `app/` and `backend/`:
no birthdate, no age field, nothing on the register or Google-signin path.
Anyone of any age can create an account.

That matters more for Reacti than for a normal chat app, because the
north-star flow **auto-captures the viewer's face** when they open a media
message. If the viewer is a child, the app has recorded a minor without a
deliberate act by that minor.

**What this plan does:** keeps under-age users from creating accounts, and
gives you a defensible answer to "what stops children using this?".

**What it does NOT do:** it does not stop adults sending images *of* children,
and it is not a moderation system. A self-declared birthdate is bypassable by
lying — every consumer app has this ceiling. It is the industry-standard
control, not a perfect one.

Store age rating (4+ → 16+) is a separate, metadata-only change and is **not**
part of this plan; it neither requires nor is required by the gate.

## Decisions — LOCKED (Achia, 2026-08-14)

| # | Decision | Locked answer |
|---|---|---|
| **AG1** | Minimum age | **16.** One worldwide rule, no per-country branching. Lives in `config/reacti.php` → `min_age`; never inline the number. |
| **AG2** | Existing users (no DOB on file) | **A one-time age confirmation at launch**, not a DOB backfill. Shown only to accounts whose `date_of_birth` is null, so new users are never asked twice. Lighter than the original A4. |
| **AG3** | What we store | **DOB**, server-side only. In `$hidden` on the model; `UserResource` is an allowlist so it can't leak there. |
| **AG4** | Under-age UX | **Hard stop.** No user row is ever created — the rule refuses before the OTP is even cached. |

Store rating is **not** part of this plan: Apple computes it from the rating
questionnaire and there is no field that sets it directly. The gate and the
rating are independent.

## Phases

Each phase = one branch off `develop` = one PR, per repo convention.

### A1 — Backend: field, validation, migration · `feat/age-gate-backend` · S

* Migration: `users.date_of_birth` — `date`, **nullable** (existing rows have
  none; A4 fills them if you pick that route).
* `UserRegisterRequest` (`backend/app/Http/Requests/Auth/UserRegisterRequest.php`):
  add `'date_of_birth' => ['required', 'date', 'before_or_equal:' . now()->subYears(MIN_AGE)->toDateString()]`
  plus a human message ("You must be at least 16 to use Reacti.").
  Min age as a single config constant (`config/reacti.php` → `min_age`), not a
  literal sprinkled through the code.
* `AuthService::register()` (`backend/app/Services/AuthService.php:42`) carries
  `date_of_birth` through the OTP cache payload (`$cacheData`, line 62) so it
  survives the verify step and lands on the created user.
* **Never trust the client**: the rule above is the enforcement point. The
  client-side picker is UX, not security.
* `UserResource` must **not** expose `date_of_birth` to other users. Own-profile
  only, if at all.

**Tests:** register with DOB under the threshold → 422 with the message;
exactly on the boundary (birthday today) → passes; missing DOB → 422; DOB
survives OTP verify onto the user row.

### A2 — Client: the age step · `feat/age-gate-signup` · S–M

* `app/lib/features/auth/presentation/signup/signup_screen.dart` — add a date
  field alongside the existing name/email/phone/password fields (that form
  already has the validator pattern to copy, lines ~243-347).
* **Neutral entry**: a plain date picker with no "you must be 16" hint *before*
  input. Showing the threshold first just teaches people what to type. The
  message appears only after a failing date.
* Native `showDatePicker` — no new dependency. `initialDate` set well back
  (e.g. today − 25 years) so the wheel doesn't start at "today" and imply that
  a newborn is acceptable.
* Payload: `app/lib/features/auth/data/rx_signup/api.dart` `signup()` gains a
  `dateOfBirth` param → `"date_of_birth"` in the map (line ~42).
* Under-age result → a dead-end screen ("Reacti is for 16 and over"), no
  account created, no retry loop back into the form on that launch.

**Tests:** widget test for the field + failing/passing date; the existing
signup tests updated for the new required field.

### A3 — Google sign-in path · `feat/age-gate-social` · M

**This is the hole that's easy to miss.** `SocialLoginController::socialSignin`
(`backend/app/Http/Controllers/Api/Auth/SocialLoginController.php:45`) creates
an account straight from a Google token — it never touches
`UserRegisterRequest`, so A1's rule does not cover it. Google does not hand us
a birthdate.

Approach: for a **new** Google user, the endpoint returns the account in a
"needs DOB" state and the client shows the same age step before the session is
usable; the account only becomes usable once a valid DOB posts. Existing Google
users are untouched (they fall to A4).

**Tests:** new Google user without DOB cannot reach authenticated endpoints;
posting an under-age DOB refuses and cleans up.

### A4 — Existing users: one-time age confirmation · `feat/age-gate-confirm` · S–M

Per AG2 this is a **confirmation**, not a birthdate backfill: a one-time
screen at launch for accounts with `date_of_birth = null`, stating the
minimum age and asking the user to confirm they meet it. Mirrors the DG1
consent gate that already exists — reuse that pattern rather than reinvent.

* Server records the confirmation (a nullable `age_confirmed_at` timestamp),
  so it can't be dodged by reinstalling.
* **Weaker than a birthdate by design** — a confirm button is one tap and
  anyone can tap it. It is what makes the existing base cheap to cover; the
  real gate is A1 on new signups.
* **Open lawyer question:** what happens to an existing user's chats and media
  if they decline. Refuse-and-delete vs refuse-and-retain is not an
  engineering call. **A4 does not ship until this is answered.**

### A5 — Copy, policy, store answers · `docs/age-gate-copy` · S

* Minimum age stated in the terms/EULA and on the privacy-policy page the
  backend already serves (`backend/routes/web.php` → `privacy-policy`).
* App Store Connect: the age-rating questionnaire's UGC/chat answers are what
  actually move the rating; the gate itself doesn't change them.
* Analytics (PostHog, already wired): `age_gate_shown`, `age_gate_passed`,
  `age_gate_blocked` — so you can see how many people the gate turns away.

### A6 — OPTIONAL: Apple's Declared Age Range API · S–M

The App Store questionnaire item you hit ("*at a minimum, the Declared Age
Range API is called…*") refers to a **specific iOS API** that returns an
OS-level, parent-approved age range. Adopting it is the only way to answer
that question truthfully. It needs a small platform channel — there is no
Flutter plugin in the project today. Only worth doing if you decide to answer
Yes to Apple's social-media questions, which per my earlier read you should
not.

## Order and gating

A1 → A2 → A3 are one shippable unit; **A3 is not optional** — shipping A1+A2
alone leaves Google sign-in as an open door. A4 ships behind AG2. A5 goes with
the release.

Nothing here touches the patent flow (blur/unblur, `recordVideoSilently()`,
`mark-viewed`, reaction upload), so the patent suite should stay green
untouched — but run it anyway before merge, per CLAUDE.md.

## Estimate

A1 ~half a day, A2 ~half a day, A3 ~a day (the fiddly one), A4 ~a day,
A5 an hour. Call it **3-4 days** including staging verification per feature,
which is the cadence you've been running.
