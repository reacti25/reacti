# Walkthrough v2 — teaching the mechanics

**Status:** proposed, awaiting Achia's approval
**Supersedes nothing** — extends `docs/PLAN-onboarding-walkthrough-2026-08-15.md`
(shipped as PRs #411–#414).

## The gap

v1 ships three coach marks over the home screen: Chat tab, Friends tab, new
group. That answers *where things are*. It does not answer the two questions a
new user actually has:

1. How do I send a photo or video?
2. What is a "Reacti"? What happens when I open something someone sent me?

(2) is the product. A user who never learns it has installed a slower
WhatsApp.

## Why this cannot just be "more steps in the tour"

A brand-new account is empty. There is no sealed message to point at, no
reaction to point at, no thread to point at. A linear 10-step tour on first
launch would spend seven of its steps highlighting empty boxes — the same
constraint that shaped v1.

So v2 is not a longer tour. It is a **trail**: the three home marks stay as
the only thing that fires up front, and every other lesson is a one-time tip
that fires the first time the real situation appears. The user learns "this is
a sealed message" while looking at their first actual sealed message.

Rules that keep it from becoming a popup wall:

* one tip per screen visit, never two at once;
* every tip fires at most once per install, gated on its own GetStorage flag;
* every flag is cleared by **Profile → Replay walkthrough**;
* nothing here may change the blur/unblur transition, the recording trigger,
  or the reaction upload path.

## Phase W1 — the send path (3 tips)

Where the user is: a 1:1 chat they just opened for the first time.

| # | Target | Copy |
|---|--------|------|
| T1 | composer attach button *(shipped)* | "Send a Reacti — send a photo or video, and get their real reaction back." |
| T2 | media picker sheet, select control | "Tap more than one to send a batch." |
| T3 | preview screen, caption + send | "Add a caption and send. It arrives sealed — they can't see it until they open it." |

T3 is where the sender-side concept lands: *what I send is hidden until they
open it*. Files: `widget/media_picker_sheet.dart`,
`media_preview_screen.dart`.

## Phase W2 — the receive path (2 tips) — the important one

| # | Target | Copy |
|---|--------|------|
| T4 | the first sealed tile this user is ever shown, in any thread | "Sealed. Tap to open — your camera captures your reaction and sends it straight back." |
| T5 | the first reaction message that comes back | "That's their reaction, recorded the moment they opened what you sent." |

T4 is the one lesson that is worth the whole plan, and it is also the one with
teeth:

* it lives in `widget/receiver_message_widget.dart`, on the patent path;
* the mark wraps `_buildBlurPlaceholder` **visually only**. Coach marks in this
  app run with `disableDefaultTargetGestures: true`, so the first tap dismisses
  the tip and the second opens the media. The tap that triggers
  `mark-viewed` → `recordVideoSilently()` is never intercepted or synthesised;
* it must not fire while a reveal is in flight;
* per `CLAUDE.md`, it needs a regression test exercising the full loop with the
  tip armed, proving the recording still fires.

T5 lives in `widget/receiver_message_widget.dart` too (a reaction arrives as a
`type: "reaction"` message) and needs no special care — reactions never seal.

T4 also happens to be the clearest place we tell a user, in the product, that
opening media turns on their camera. Worth keeping in mind next to the age-gate
and consent work.

## Phase W3 — thread controls (1 tip) — optional

| # | Target | Copy |
|---|--------|------|
| T6 | the user's own third message in a thread | "Long-press any message to reply, forward, edit or delete." |

Cheapest of the three phases and the least necessary — long-press is a gesture
most people try anyway. Include it or drop it.

## Wiring

* one `kKeyTour*Seen` constant per tip, all added to `FirstRunTour.resetAll()`;
* reuse `FirstRunTour.showOnce` unchanged — it already refuses to burn a flag
  on an unmounted target, which is exactly what T4/T5 need when a message
  scrolls in off-screen;
* one flag test per tip, plus the patent regression for T4.

## Shape of the work

Three PRs off `develop`, one per phase, staging build after each per the usual
cadence. W2 is the one that needs on-device eyes; W1 and W3 are ordinary UI.

**Recommendation: build W1 and W2, skip W3.** W1 + W2 close both questions a
new user actually has; W3 teaches a gesture people find by accident.
