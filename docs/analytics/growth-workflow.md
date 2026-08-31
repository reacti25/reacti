# Reading the growth numbers

Companion to `docs/analytics/perf-workflow.md`, which covers speed. This one
covers people: who arrives, whether they get to the point of the app, how long
it takes them, and whether they come back.

It exists so these questions get answered by running two commands rather than
by asking someone to write a query.

---

## The two commands

```sh
# App side: funnel, walkthrough, country, permissions, sign-in, retention.
export POSTHOG_READONLY_KEY=phx_...
python scripts/analytics/growth_digest.py --env production --days 30

# Web side: what the invite link did. Run on the server.
php artisan invites:digest --days=30
```

Both are read-only. Both report counts and medians, never a person.

Run them against `--env staging` first when you want to check a change works
before it reaches real users. Staging numbers are tiny and made mostly of our
own testing, so treat them as "is this recording at all", never as a result.

---

## Section by section

### Activation funnel

```
ACTIVATION FUNNEL           people    of prev   median from launch
  App opened                    412         -           2s
  Signup started                180       44%          41s
  Email verified                149       83%          3m
  Account created               141       95%          4m
  First friend                   88       62%          22m
  First Reacti sent              61       69%          35m
  First reaction back            44       72%          2.1h
```

**people** counts distinct people, not events, so someone opening the app forty
times is one person.

**of prev** is the share who got here from the step above. This is the column
to read first: the smallest percentage is where the app is losing the most
people, and it is almost always worth more than any improvement further down.

**median from launch** is how long it took a typical person to get here,
counted from the first time they ever opened the app. This is time-to-value.
The research is consistent that the faster people reach the first real moment
of value, the more of them stay.

**end to end** at the bottom is the fraction of everyone who opened the app who
finished the whole loop. That single number is the honest headline.

What to do with it: fix the worst **of prev** first. A leak high in the funnel
caps everything below it, so a better walkthrough cannot rescue a signup step
that is losing half its people.

### Walkthrough

```
WALKTHROUGH               people   activated    rate
  saw it                     190          71     37%
  did not                    151          19     13%
```

Whether people who saw the walkthrough went on to send a first Reacti, against
people who did not.

**This is correlation, not proof.** People who sit through a walkthrough are
keener to begin with, so some of any gap is that keenness rather than the
walkthrough. A large, stable gap is still the strongest evidence available
short of showing it to a random half of new users and comparing.

Read it as: if the gap is large, the walkthrough is at worst harmless and
probably helping. If there is no gap at all after a few hundred people, the
effort is not paying and the design is worth rethinking rather than polishing.

### Where they are

Coarse country, from the device's language setting. Not from an IP address, not
a location permission, and not precise. It is here to answer "who is finding
this and where", and it is the only geography collected.

### Permissions

```
PERMISSIONS               asked   granted   denied
  camera                    188       74%      26%
  microphone                188       74%      26%
  notifications             204       61%      39%
  contacts                  151       55%      45%
```

Read the **camera** line first, and read a denial there as a lost user rather
than a preference. Someone who refuses the camera cannot send a reaction at
all, which is the entire app. In every other section of this digest they look
exactly like a person who chose not to bother, and treating those two the same
would point the product at the wrong problem.

**notifications** is the return path. A high denial rate here caps retention no
matter what else improves, because nothing pulls those people back.

**contacts** sits between "account created" and "first friend" in the funnel,
so if that step drops, check this line before redesigning the screen.

Each person is counted once, at their **latest** answer. Someone who denies and
later allows shows as granted, not as both.

### Signing in and leaving

```
SIGNING IN & LEAVING       people
  Signed in                   240
  Sign-in failed               31   11% of attempts
  Removed a friend              9
  Left a group                  4
  Deleted their account         2
  Median session               4m
```

**Sign-in failed** covers returning users only. The activation funnel is about
new accounts, so before this existed a person locked out of their own account
was invisible: they simply stopped appearing. A rising share here is a bug, not
a change in demand.

**Removed a friend / Left a group / Deleted their account** are the deliberate
exits. Retention tells you someone stopped coming back; these tell you they
chose to go. The two need opposite responses, and the counts are usually small
enough that any sustained rise is worth looking into directly.

**Median session** separates opening the app from using it. Someone opening it
daily for four seconds is not retained in any sense that matters, and retention
alone cannot see the difference.

### Rolling retention

```
ROLLING RETENTION          kept   of eligible
  D1                        118       43%  (n=274)
  D7                         52       26%  (n=201)
  D30                        19       14%  (n=136)
```

Each line asks a different question:

* **D1** did the first session land, or did they open once and never return?
* **D7** did a habit start forming?
* **D30** is there durable value worth keeping the app installed for?

Two things about how these are counted, because both change what the numbers
mean:

**Rolling.** "Kept at D7" means seen on or after day seven, not specifically on
day seven. At Reacti's current volumes a day-boxed number swings wildly on a
handful of people, so rolling is the steadier read.

**Only the eligible are counted.** Someone who installed yesterday cannot have
a D30 outcome yet, so they are left out of the D30 denominator instead of being
counted as lost. The `(n=...)` on each line is that denominator. Without this,
the numbers appear to collapse whenever the app grows, which is the most common
way a retention chart lies.

Published benchmarks for social and messaging apps vary a great deal by source,
and the flattering ones describe top-decile apps. The useful comparison is
Reacti against itself over time, not against a number from an article.

### Invite loop

```
Invite loop  |  last 30d
  Links minted                    140
  Links opened at least once       61   44% of links
  Opens in total                  203   3.3 per opened link
  Demo completed                   77   38% of opens
  Store tapped                     44   22% of opens
```

**Links minted** is how many people generated their personal link. **Links
opened** is how many of those links anyone actually followed. The gap between
them is people who took a link and never shared it, which is its own thing to
fix and is invisible if you only count opens.

**Opens in total** counts every open including repeats, because a link dropped
into a group chat gets opened many times and that reach is the point.

**Demo completed** and **Store tapped** are shares of opens, and together they
answer whether the web demo earns its place: if plenty of people finish the
demo but few tap through to the store, the demo is entertaining and not
persuading.

---

## Putting the two halves together

The invite loop crosses two systems, and neither command can see the whole
thing:

* the web half, up to the store tap, is in `php artisan invites:digest`
* the app half, install onward, is `invite_opened` and `invite_connected` in
  the growth digest

**K-factor**, the number that says whether the app grows by itself, is roughly:

> K = (links opened per person who minted one) x (share of those opens that
> became a connected new user)

Above 1.0 means each user brings more than one more and growth compounds. Below
it means invitations help but do not sustain growth on their own. Getting the
second half of that multiplication needs both commands read together, so it is
deliberately not printed as a single figure: a number that looks precise and
quietly joins two different systems is worse than no number.

---

## What still cannot be answered here

**Time from downloading to first opening the app.** The app can only start
counting at first launch; the download moment exists only in App Store Connect.
Read downloads there and compare by hand if it matters.

**Which advert or post someone came from.** Since Apple's tracking rules, that
needs either consent from about a third of users or aggregated store-level
reporting, and it only applies to paid advertising, which Reacti does not do.
The invite link already gives first-party attribution for the channel Reacti
actually uses. Revisit if paid ads ever start.

---

## Privacy

Everything above is counts and medians. No message text, no media, no camera
footage, no names, emails or phone numbers, and no precise location. The
analytics opt-out is honoured before anything is sent. The landing page carries
no third-party script and sets no tracking cookie, which is why its numbers are
counters on a row Reacti owns rather than analytics events.

To be exact about the landing page, since it is the one public page and the
only one a person without the app ever sees: it does set Laravel's own session
and CSRF cookies, as every page on the site already did before any of this was
added. Those are first-party and functional, they carry no identifier used for
analytics, and nothing here changed them. What the page does not do is load a
third-party script or set anything that follows a visitor elsewhere. See
`docs/analytics/privacy.md`.
