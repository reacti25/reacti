# App Lock with Face ID

**Status:** plan, awaiting Achia's approval. Nothing built.

**Ask (Achia, 2026-08-27):** can the app support iPhone face recognition, so
someone gets into their account with it — and what would that mean?

---

## The framing that decides the design

**Reacti already keeps people signed in.** The access token lives in the iOS
Keychain (`AuthTokenStore` → `flutter_secure_storage`) and the JWT runs for
**30 days** (`JWT_TTL = 43200` minutes). Opening the app drops straight into
the chat list. There is no login screen to put Face ID in front of.

So this is **not** a login feature. It is a **lock on an app you are already
signed into** — and named honestly, "App Lock", not "Login with Face ID".

Which is worth more here than in most apps. Reacti threads contain **videos of
people's faces**, recorded in private moments, of people who are not the phone's
owner. Anyone holding an unlocked phone can open Reacti today and watch all of
them. That is the threat this closes, and the people it protects are as much the
user's friends as the user.

**What it is not:** the check is local. iOS answers yes or no; no face data is
read, stored or transmitted by Reacti, and the server never learns anything. It
does not make the account harder to break into remotely — the password still
does that. Anyone who wants *account* security wants a second factor at login,
which is a different feature (see "Not this").

---

## Behaviour

**Off by default.** Turned on in Profile → App Lock. Never enabled for someone
without asking; a security feature that surprises you is a lockout.

**When it asks**, following WhatsApp, whose model people already know:

| setting | prompts |
| --- | --- |
| Immediately | every time the app is foregrounded |
| After 1 minute | if backgrounded longer than a minute |
| After 15 minutes | if backgrounded longer than fifteen |

A prompt on every app switch is unbearable — pick a photo to send, come back,
scan your face. The grace period is what makes it liveable, and *Immediately*
must not be the only option.

**Fallback is mandatory, not a nicety.** Face ID fails constantly in real life —
masks, dark rooms, sunglasses, a sibling's face, a phone with no Face ID at all.
`biometricOnly: false` lets iOS fall back to the **device passcode**, so the
lock is never the last word. Without it a bad scan locks someone out of their
own account and the only way back is deleting the app.

**Locked state shows nothing.** A full-screen cover over the app, not a dialog
over the chat list — a screenshot of the locked screen must not leak the last
thread. It carries one button, "Unlock", so a dismissed prompt is recoverable.

---

## What it touches

* `local_auth` — the only new dependency. Official Flutter plugin.
* `ios/Runner/Info.plist` — **`NSFaceIDUsageDescription`** is required. Without
  it iOS refuses and tells the user the app has not been updated for Face ID.
* `android/.../MainActivity.kt` — **must become `FlutterFragmentActivity`**.
  Ours is a plain `FlutterActivity`, and `local_auth` needs a `FragmentActivity`
  or it throws at runtime. Android is not shipping today, but the debug build is
  a required CI check, so this cannot be skipped.
* A lock gate around the app, plus the Profile setting.
* `AppLifecycleState` to time the grace period.

The lock lives **above** the existing session, so nothing about login, the token
or `AuthTokenStore` changes. Being locked out of the lock never means being
logged out.

---

## Phases

**L1 — the setting, inert.** `local_auth` added, capability detected, Profile
row with the on/off and the three timings, persisted. Nothing locks yet.
Shippable on its own; proves the plugin builds on both platforms before any
behaviour depends on it.

**L2 — the lock.** The cover screen, the lifecycle timer, the prompt, the
passcode fallback. Behind the L1 setting, so it can only affect someone who
asked for it.

**L3 — the edges.** Biometrics removed or changed on the device (iOS
invalidates them; the setting must not become an unopenable door), no biometrics
enrolled at all, repeated failures, and turning the setting off — which must
itself require an unlock, or the lock is decoration.

## Testing

The plugin is a platform channel, so the prompt itself is not unit-testable.
What is:

* the grace-period decision — a pure `shouldLock(lastBackgrounded, now, setting)`
  covering each timing, the boundary, and a clock that jumps backwards;
* the setting's persistence and its default (**off**);
* a widget test that the cover screen hides its content;
* that turning the lock off demands an unlock first.

An on-device pass is required regardless: this is a feature whose entire value
is what a real phone does with a real face.

## Risks

* **Lockout is the failure that matters.** Everything above — passcode
  fallback, off-by-default, an explicit Unlock button, the L3 invalidation
  handling — exists for it. Worth stating plainly: a bug here does not degrade
  the app, it takes someone's account away from them.
* **Android's `FlutterFragmentActivity` change** touches app startup for every
  Android build. Small, but not cosmetic.
* **Grace-period frustration.** If it re-prompts too eagerly people turn it off
  and are worse protected than before. Default to **After 1 minute**, not
  Immediately.

## Not this

**Face ID as a second factor at login** — proving *to the server* that the
device holder is the account owner. That is a genuinely different feature
(device keys, a server-side challenge, an enrolment flow) and much larger. If
what is wanted is "harder to break into my account from another phone", say so
and it should be planned separately. This plan protects a phone in someone
else's hands, and nothing else.

## Recommendation

Build **L1 and L2**, then look at it on a staging build before L3. It is opt-in
and off by default, so the blast radius is limited to whoever turns it on —
which at first is Achia.
