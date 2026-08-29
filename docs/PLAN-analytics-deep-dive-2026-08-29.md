# What to measure about new users, and what Reacti is missing

**Status:** research + proposal, awaiting Achia's decisions. Nothing built.

**Ask (Achia, 2026-08-29):** we put a lot of effort into new users — the demo,
the walkthrough, invites. She wants analytics covering every angle of how the
app is used: who the new users are, where they are from, how they behave when
they arrive by invitation, how they found the app, how long from download to
first use. Research what other apps measure, then say what Reacti should add.

---

## Part 1: how the industry thinks about this

Four frameworks matter here. They overlap; each answers a different question.

### AARRR — the standard shape of a growth funnel

**Acquisition → Activation → Retention → Referral → Revenue.** Nearly twenty
years old and still the default. Reacti has no revenue, so four stages apply.

The stage everyone agrees is most leveraged is **Activation**: getting someone
to the first moment of value fast. The literature's phrase is the *aha moment*,
and the operational metric is **time-to-value** — the longer it takes, the more
people leave before reaching it.

### Time-to-value and the activation event

The strongest finding in the retention research: **day-1 completion of a
meaningful first action is the single best predictor of day-30 retention**, and
apps that get first-session activation right retain at two to three times the
rate of apps that do not.

Which means the number that matters most is not installs. It is *what fraction
of new accounts complete the one action that is the point of the product, and
how long it took them*.

### Retention cohorts — D1 / D7 / D30

The standard reporting shape, and each day answers a different question:

* **D1** — did onboarding land?
* **D7** — did a habit form?
* **D30** — is there durable value worth keeping the app for?

Published benchmarks for social/messaging vary widely by source — one puts
strong performers at D1 50-70% / D7 30-50% / D30 25-50%, another puts the
category nearer D1 25-29% / D7 9-10% / D30 5%. The honest reading is that the
high numbers describe top-decile apps. Two things are worth taking from it
rather than the numbers themselves: **a leak upstream caps everything
downstream** (D7 cannot be fixed without D1), and the **median app keeps under
4% of installs by day 30**.

### K-factor — the metric for a product that grows by invitation

**K = (invites sent per user) × (invite conversion rate).** Above 1.0 each user
brings more than one more, and growth compounds without paid acquisition.

This is the framework that fits Reacti most precisely, because Reacti is
already built around it: a personal invite link, a web demo for people who have
not installed, and Universal Links that connect the two accounts on open. That
is a viral loop, and **nothing currently measures whether it works**.

### Attribution — "how did they find us", and why it is hard now

Worth being blunt about this one, because it is the part of her question with
the least satisfying answer.

Since App Tracking Transparency, per-user attribution on iOS is mostly gone.
Consent rates sit around **25-35%**, and without consent the only mechanism is
**SKAdNetwork**, which returns *aggregated, delayed* postbacks — "this campaign
drove 50 installs" — 24 to 72 hours later, never tied to a person.

**But Reacti's main channel is not ads, it is invites** — and an invite link is
a first-party signal that no privacy framework touches. Reacti can know
precisely which invite led to which install, because it minted the code.

So the recommendation is to instrument the channel Reacti actually has, and not
to buy an attribution SDK for a channel it does not use yet.

---

## Part 2: what Reacti has today

Better than expected. PostHog (EU) and Sentry, live in staging and production
since June, honouring an opt-out, with no message text, media, camera footage,
names, emails or numbers collected. Identity is a random per-launch id.

**33 events are defined. 24 fire. Nine do not**, and they are conspicuously the
ones this question needs:

| defined but never fired | what it would have told us |
| --- | --- |
| `registerStarted` | how many people begin signing up |
| `otpVerified` | where the email step loses them |
| `firstMessageSent` | **the activation moment** |
| `friendAdded` | whether they got past an empty account |
| `reactionViewed` | whether the loop actually closes |
| `groupCreated`, `groupJoined` | group adoption |
| `consentDecision` | consent outcomes |
| `sessionStart` | session shape |

So the signup funnel currently records only its final step (`signupCompleted`),
and the single most predictive metric in the whole literature — did a new user
complete a meaningful first action — is defined in the code and never sent.

---

## Part 3: the gaps, in priority order

### G1 — The activation funnel is not measured (highest value)

Nothing answers "what fraction of new accounts send their first Reacti, and how
long did it take". Fire the events already defined, and add a
`first_reaction_received` for the moment the loop closes — the actual aha, since
a Reacti is not a Reacti until a face comes back.

The chain to measure, each step with elapsed time from install:

> install → `registerStarted` → `otpVerified` → `signupCompleted` →
> `friendAdded` → `firstMessageSent` → `first_reaction_received`

That gives time-to-value directly, and shows which step loses people.

### G2 — The walkthrough and demo are unmeasured

Two features have been built and rebuilt for weeks on Achia's judgement and
Jonjon's, with no data on whether either helps. `demoStarted` and
`demoReactionCompleted` fire; the walkthrough fires nothing at all.

Worth adding per step, which is the standard onboarding-analytics shape
(`step_started` / `step_completed` with the step as a property): the card, each
tip shown, each dismissed, and whether the walkthrough was replayed. The
question it answers is whether people who complete it activate at a higher rate
than people who do not — which is the only way to know if the effort is paying.

### G3 — The invite loop is not measured end to end

`inviteShared`, `inviteOpened` and `inviteConnected` all fire, which is a good
start, but the web landing page — the thing a person without the app actually
sees — sends nothing. The full loop needs: link opened on web → demo watched →
store tapped → app installed → account created → connected to the inviter.

That yields **K-factor**, and tells us whether the web demo earns its keep.

### G4 — "Where are they from" is not captured

No country, no locale, no timezone. All three are inferable from the request
without asking anyone anything, and country is a coarse, non-identifying
property.

Worth noting the honest limit: **PostHog can derive country from IP
server-side**, so this may be partly answerable already without shipping
anything. Check the existing data before building.

### G5 — Time from download to first use cannot be answered exactly

Her question was "how long from downloading to first use". The exact figure
needs store-level data: **App Store Connect reports impressions, product-page
views, downloads and re-downloads**, and that is the only place the download
moment exists. The app can only start counting at first launch.

So: first launch → signup → activation is measurable in-app; download → first
launch needs App Store Connect, read separately and joined by hand.

### G6 — Retention cohorts are not set up

PostHog does this natively once a stable person id exists. It needs checking
that the identity model supports cohorting across sessions, since identity is
currently a per-launch random id with a hashed user id on login.

---

## Part 4: what I would do

**Phase A — fire what already exists.** The nine dead events, plus install-to-
step timings. Small, no new dependency, and it makes the activation funnel and
time-to-value answerable immediately. Highest value per hour by a distance.

**Phase B — instrument the walkthrough and demo per step.** Answers whether the
last month of onboarding work actually helps.

**Phase C — close the invite loop across the web landing page.** Gives
K-factor, and tells us whether the web demo converts.

**Phase D — the dashboard.** Cohorts, funnels and a saved view per question, so
these are answered by looking rather than by asking me to query.

**Not recommended:** a paid attribution SDK (AppsFlyer, Adjust, Branch). They
solve paid-acquisition attribution, which Reacti does not do, and they cost
money and carry a privacy surface. The invite link already gives first-party
attribution for the channel that matters. Revisit if paid ads ever start.

## Decisions needed from Achia

1. **Phases A-D, or a subset?** A alone is most of the value.
2. **Country:** is coarse country acceptable to collect? (It is
   non-identifying and standard, but it is her call, and the privacy copy
   currently promises quite a narrow list.)
3. **Does anything here change the analytics opt-out wording?** New events do
   not change what is promised — still no content, no identity — but the
   consent copy should be re-read once the list grows.
