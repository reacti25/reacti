# Google Play paperwork — DRAFT for Achia's review

**Status: draft, 2026-10-08.** Step 9 of
`docs/PLAN-android-and-play-store-2026-09-28.md`. Google blocks the closed test
until every item here is filled in under Play Console → **App content** and
**Main store listing**, and it reviews what is submitted. Nothing here is legal
advice: it describes what the code does, so it can be transcribed or handed to
a lawyer.

Items marked **CONFIRM** need an answer from Achia before they go in.

---

## 1. Store listing

**App name** (30 characters max): `Reacti`

**Short description** (80 characters max, 78 used):

> Send a photo or video and get your friend's real reaction the moment they open it

*(Shorter alternative, 63: "See your friend's real reaction the moment they open your photo")*

**Full description** (4,000 max):

> Reacti is a messaging app built around one moment: the instant your friend
> opens what you sent.
>
> Send a photo or video to a friend or a group. It arrives blurred. When your
> friend taps to open it, Reacti uses their front camera to capture their
> reaction for a few seconds, and sends that reaction back to you. You don't
> just know they saw it. You see how they felt.
>
> HOW IT WORKS
> • Send photos and videos to friends and groups
> • They open it, and their front camera captures their reaction
> • Their reaction comes straight back to you in the chat
> • Everyone knows how Reacti works before their first reaction: the app
>   explains it and asks for camera permission first
>
> ALSO IN REACTI
> • One-to-one chats and group chats
> • Send several photos and videos at once, with a caption
> • Edit and draw on photos before sending
> • View-once media
> • Invite friends with a personal link
> • App lock with your fingerprint or a passcode
>
> Reacti is for people aged 16 and over.

Why the description says it so plainly: Google's **Deceptive Behavior** policy
targets apps that use the camera in ways people don't expect. Capturing the
recipient's reaction is the whole product, so the listing states it in the
second paragraph, before any feature list.

**CONFIRM:** the description matches how you describe Reacti on the App Store.
Edit freely; keep the "front camera captures their reaction" sentence.

**Graphics** (Achia, or exported from the iOS assets):
- App icon: 512 × 512 PNG (the existing icon, no transparency).
- Feature graphic: 1024 × 500.
- Phone screenshots: at least 2 (up to 8), 16:9 or 9:16. Suggest: chat list, a
  blurred photo, the reaction arriving, group chat, the gallery picker.

**Contact details:** email (the one you read), website `https://reacti.io`,
privacy policy `https://reacti.io/privacy-policy`.

---

## 2. App content declarations

### Privacy policy
`https://reacti.io/privacy-policy`. **CONFIRM** it mentions Android / Google
Play, push notifications via Firebase, and the analytics paragraph from
`docs/analytics/app-store-privacy-declaration.md`. The text lives in the
database (DynamicPage), not in the repo.

### App access
Reviewers must be able to use the core flow, so: **"All or some functionality
is restricted"**, with a review account that already has a friend and a Reacti
to open. **CONFIRM:** is there an App Store review account we can reuse? It
must exist on **production**.

### Ads
**No**, the app does not contain ads.

### Content rating (IARC questionnaire)
Category: **Communication** (or Social). Answers, from what the app does:
- Violence, sexuality, language, controlled substances, gambling: **No** (the
  app doesn't contain such content itself).
- Users can interact or exchange content with each other: **Yes**.
- Users can share user-generated photos and videos: **Yes**.
- Shares the user's current location with other users: **No**.
- Digital purchases: **No**.
- Unrestricted internet access / web browser: **No**.

The resulting rating is computed by IARC. **Target audience** (separate
section): select **16–17** and **18+** only, matching the App Store's 16+ and
the server-side age gate (minimum 16). Not "designed for children".

### Data safety
Mirrors the App Store App Privacy declaration. Google's wording differs:
"collected" = leaves the device; "shared" = sent to a third party that is not
your service provider. PostHog, Sentry and Firebase process data on Reacti's
behalf, so nothing is "shared".

Overall answers:
- Collects or shares any required user data types: **Yes**
- All collected data is **encrypted in transit**: **Yes** (HTTPS everywhere)
- Users can request that data be deleted: **Yes**, in the app (Settings →
  Delete account) and via the account deletion web page (section 3)

| Google data type | Collected | Shared | Optional? | Purposes |
|---|---|---|---|---|
| Personal info → Name | Yes | No | No | Account management, App functionality |
| Personal info → Email address | Yes | No | No | Account management |
| Personal info → User IDs | Yes | No | No | Account management, App functionality |
| Personal info → Phone number | Yes (sign-up field, optional: `UserRegisterRequest` `phone` is nullable) | No | **Yes** | Account management, App functionality |
| Personal info → Other (date of birth, age gate) | Yes | No | No | App functionality (age check) |
| Photos and videos → Photos | Yes | No | No | App functionality |
| Photos and videos → Videos | Yes (sent videos **and the reaction recordings**) | No | No | App functionality |
| Audio → Voice or sound recordings | **Yes** (reactions record audio) | No | No | App functionality |
| Messages → Other in-app messages | Yes | No | No | App functionality |
| Contacts | Yes (phone numbers sent to find friends) | No | **Yes** (user can decline) | App functionality |
| App activity → App interactions | Yes | No | **Yes** (Settings → Usage Data) | Analytics |
| App info and performance → Crash logs, Diagnostics | Yes | No | **Yes** (same switch) | Analytics, App functionality |
| Device or other IDs | Yes (push token; Sentry's random install id) | No | No | App functionality, Analytics |
| Location | **No** (country comes from the device language setting, not location) | | | |

Two answers people get wrong, and why these are right:
- **Audio:** the reaction is a video with sound, so audio recordings are
  collected even though there is no voice-message feature.
- **Device or other IDs: Yes.** Google counts per-install identifiers like the
  push token, which the app sends to the server.

### Prominent disclosure (User Data policy)
Two places where the app must explain before the system permission prompt:
- **Camera and microphone:** done (the CamMicPrimer dialog before the first
  reaction).
- **Contacts:** the Find Friends screen explains before asking. **CONFIRM** the
  wording says phone numbers are sent to Reacti to find friends.

### Government apps, financial features, health, news, COVID: **No / not applicable.**

---

## 3. Account deletion web page

Required in addition to in-app deletion. Needs from Achia: **CONFIRM** the email
address for deletion requests, and what happens to messages a deleted user
already sent (removed for everyone, or kept for the recipient?). Then a short
page at `https://reacti.io/delete-account` explaining: how to delete in the app,
how to request by email, what is deleted, what (if anything) is kept and for
how long.
