# Taking analytics to production: the App Store declaration

**Status: open. This is the one thing that must happen before the first
production build that carries analytics.**

Reacti's App Privacy declaration in App Store Connect was filled in when the
app collected no analytics at all. The next release changes that, and Apple
requires the declaration to match what the app actually does. A stale
declaration is a rejection risk on submission and a false statement afterwards.

Nothing here is legal advice. It is an accurate description of what the code
does, written so it can be transcribed into the questionnaire or handed to a
lawyer without anyone having to read Dart.

---

## What to change in App Store Connect

**App Store Connect, your app, App Privacy, Edit.**

Analytics adds two data types to whatever is already declared for the app
itself (account details, messages, media, contacts):

### 1. Usage Data, Product Interaction

* **Collected:** yes.
* **Used for:** Analytics. *(Not Advertising, not Product Personalisation.)*
* **Linked to the user's identity:** **yes.** Events carry `distinct_id`, a
  salted SHA-256 of the account id. It is pseudonymous and not reversible by an
  outsider, but Reacti can map it back to an account, so the honest answer is
  linked. Do not be tempted by "not linked" because it is hashed.
* **Used for tracking:** **no.** See the tracking section below.

This covers which screens were opened, which funnel steps were reached, how
long things took, permission answers, and session length.

### 2. Diagnostics, Crash Data and Performance Data

* **Collected:** yes.
* **Used for:** App Functionality and Analytics.
* **Linked to the user's identity:** yes, on the same basis.
* **Used for tracking:** no.

This is Sentry (crashes, errors) and the timing events (render, jank, upload,
media load).

### Nothing else changes

**Location is not declared, and the reason matters.** The `country` property
comes from the device's own language and region setting, the same setting that
decides what language the interface is in. It is not from GPS, and not from an
IP lookup: PostHog's IP geolocation is switched off explicitly in code, with a
test that fails the build if that ever changes. The app requests no location
permission of any kind. A device setting is not location data under Apple's
definitions. Worth having a lawyer confirm once, and then it is settled.

**Contact Info, User Content, Contacts and Identifiers** are unchanged by
analytics. No event carries a message, a name, an email, a phone number, a
photo, a video, a camera frame, a file path, or a push token. Each event has a
fixed list of properties it is allowed to carry, anything else is dropped
before it leaves the device, and tests fail the build if the code and the
written catalog drift apart.

---

## "Used to track you": no, and why

Apple's definition of tracking is narrow and specific: linking your data with
data from other companies' apps or websites for advertising or measurement, or
sharing it with a data broker.

Reacti does neither. There is no advertising SDK, no attribution SDK, no
third-party pixel, no data broker, and no third-party script on the invite
landing page. The analytics data goes to Reacti's own PostHog and Sentry
projects, in the EU, and is used to answer questions about Reacti.

So: **App Tracking Transparency does not apply, and no ATT prompt is needed.**
Adding one anyway would be worse than useless. It would ask permission for
something the app does not do.

---

## The privacy policy

The published policy needs a paragraph saying the app uses analytics, roughly:

> Reacti collects anonymised usage and diagnostic information (which features
> are used, how long actions take, and error reports) to understand how the app
> is working and improve it. This never includes your messages, photos, videos,
> reaction recordings, contacts, or precise location. You can turn it off at any
> time in Settings.

That last sentence is true today. The opt-out lives in **Settings, About &
Data, Usage Data**. It is honoured before any event is sent, and it switches
off Sentry as well.

---

## The order of operations

The usual app-first rule applies and is not optional here:

1. Update the App Privacy declaration and the privacy policy.
2. Submit and release the iOS app.
3. Only then approve the production backend deploy, which adds the invite
   counter columns.

The declaration is attached to the **version**, so it has to be right before
the build is submitted, not after it ships.

---

## What to expect once it is live

Numbers start empty and fill in slowly. Day-30 retention needs thirty days
before it means anything, and the first week is mostly your own testing.

The one early signal worth acting on: if a funnel step shows **zero** people
while the steps on either side do not, that is a broken event rather than a
real result.
