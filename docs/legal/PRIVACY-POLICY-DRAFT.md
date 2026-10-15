# Reacti privacy policy — DRAFT for Achia's review

**Status: draft, 2026-10-13. Not legal advice.** Written from what the code
actually does (verified in the repo). Have a lawyer read it before publishing.
It replaces the live text at https://reacti.io/privacy-policy (last updated
2024-11-28), which contains a placeholder email and misses analytics, account
deletion and the minimum age.

**Publish only after PR #475 is live in production**: the "deleted from our
servers" promises below are true only once that fix ships.

The operator, hosting and backup facts below were checked on 2026-10-14
(App Store seller record, server IP ownership, backend settings), not guessed.
A lawyer should still read it before publishing.

How to publish: https://reacti.io/admin/dynamic-page → edit the
`privacy-policy` page → paste the text from "Privacy Policy" below.

---

# Privacy Policy

**Last updated:** [date of publishing]

Reacti ("we", "us") is a messaging app built around one moment: when your
friend opens what you sent, Reacti captures their reaction and sends it back to
you. This policy explains what information Reacti collects, why, who helps us
process it, and the choices you have.

**Contact:** reacti.ai25@gmail.com
**Operator:** Achia Rosin, Israel

## 1. What we collect

**Account information.** Your first and last name, username, email address,
password (stored only in encrypted, hashed form), your date of birth (used to
confirm you are 16 or older), and, if you choose to add them, a phone number,
profile photo and cover photo. If you sign in with Google, we receive your name
and email address from Google.

**Your messages and media.** The text, photos and videos you send, and the
groups you create or join.

**Reaction videos.** This is how Reacti works: when you open a photo or video
someone sent you, the app records a short video (a few seconds) from your
front camera, including sound from your microphone, and sends it to the person
who sent the message. Before your first reaction, the app explains this and
asks for camera and microphone permission. If you don't grant it, no reaction
is recorded.

**Contacts (optional).** If you allow access to your contacts, the phone
numbers in your address book are sent to our servers only to find which of
your contacts already use Reacti. They are compared with registered users'
phone numbers and **are not stored**. You can decline, and you can withdraw
permission at any time in your phone's settings.

**Usage and diagnostic information.** To understand how the app is used and
to fix problems, the app records which features are used, how long actions
take, and error and crash reports. This never includes your messages, photos,
videos, reaction recordings, contacts, or precise location. Each record is
linked to a pseudonymous identifier derived from your account, not to your
name or email. You can turn this off at any time in **Settings → About & Data
→ Usage Data**.

**Device information.** A notification token so we can deliver push
notifications, and basic technical details (device model, operating system and
app version) included in crash reports. Your approximate country is taken from
your device's language and region setting, not from your location or IP
address. Reacti does not request location permission.

**Invite links.** When someone opens a Reacti invite link, our server records
anonymous counts of how far the invite page was used (for example, that it
was opened). The invite page uses no cookies and no third-party tracking.

## 2. How we use it

- To provide the app: create your account, deliver messages, photos, videos
  and reactions, show your friends and groups, and send notifications.
- To keep Reacti safe: enforce the minimum age, handle reports and blocks, and
  prevent abuse.
- To improve the app: understand which features work and fix errors (only
  with usage data switched on).

We do **not** sell your information, we do not show ads, and we do not use
your information to track you across other companies' apps or websites.

## 3. Who helps us (service providers)

These companies process information on our behalf, only to run Reacti:

- **Hostinger** (our main servers, in the United Kingdom) and **Cloudflare**
  (delivering photos and videos quickly).
- **Google Firebase Cloud Messaging** (push notifications).
- **Amazon Web Services** (servers in the United States): hosts the server
  that delivers messages in real time.
- **PostHog** (usage analytics) and **Sentry** (crash and error reports),
  both hosted in the EU: only while usage data is switched on.
- **Google** (only if you choose Sign in with Google).
- **Apple and Google** app stores (downloads and app updates, under their own
  policies).

We may disclose information if the law requires it.

## 4. How long we keep it

- Your messages, photos, videos and reactions stay until you or the other
  person deletes them, or until the account is deleted.
- When a message is **deleted for everyone**, a conversation or group is
  deleted, or an account is deleted, the related photos, videos and reaction
  videos are deleted from our servers.
- "Delete for me" hides a message only for you; the other person still has it.
- Copies in our backups are removed within 30 days, as backups are replaced.

## 5. Deleting your account

- **In the app:** Settings → **Delete Account**. This permanently deletes your
  account, your messages (sent and received), the groups you created, and
  their photos, videos and reaction videos.
- **Without the app:** email **reacti.ai25@gmail.com** from the email address
  on your account, with the subject "Delete my account". We will confirm and
  complete the deletion within 30 days.

## 6. Your rights

You can ask us for a copy of your information, to correct it, or to delete it,
by emailing reacti.ai25@gmail.com. Depending on where you live (for example in
the EU or Israel), you may also have the right to object to or restrict
certain processing, and to complain to your data protection authority.

## 7. Age

Reacti is for people aged **16 and over**. We check your date of birth at
sign-up. If you believe someone under 16 has an account, contact us and we
will delete it.

## 8. Security

Information travels between the app and our servers over encrypted
connections (HTTPS), and passwords are stored only in hashed form. No system
is perfectly secure, but we work to protect your information.

## 9. Changes

If we change this policy, we will update the date above and, for important
changes, tell you in the app.

## 10. Contact

Questions or requests: **reacti.ai25@gmail.com**

---

## Evidence behind the facts (not part of the published text)

- **Operator:** App Store seller of Reacti (id6755814897) is "Achia Rosin";
  Play Console account is a personal account in the same name.
- **Main servers:** the VPS 72.61.202.136 belongs to Hostinger International
  (AS47583), located in Manchester, United Kingdom. reacti.io is behind
  Cloudflare.
- **Real-time server:** the backend broadcasts with Laravel Reverb to
  `climbiq-goonclimbers.com` (production settings, `BROADCAST_CONNECTION=reverb`,
  `REVERB_HOST`); the app connects to it on port 8081. It resolves to
  54.160.206.108, Amazon (AS14618), Ashburn, Virginia, US. It was set up by the
  original development team; moving it onto Reacti's own server is a separate
  follow-up (see NEEDS-ACHIA.md, A2).
- **Backups:** 30 days is the commitment; Hostinger backups rotate, so deleted
  data ages out of them within that window.
- **Transfers:** data reaches the UK (Hostinger) and the US (AWS, Google
  Firebase). PostHog is EU-hosted; Sentry is EU-hosted too (its DSN host is
  ingest.de.sentry.io, Germany).
