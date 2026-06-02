# Setting up iOS releases from CI

This is the **one-time setup** that lets you ship to TestFlight (and
then the App Store) without ever opening Xcode on a Mac.

## Goal

After this is set up:

1. You tag a release locally:   `git tag v1.0.10 && git push --tags`
2. GitHub Actions builds and signs the iOS app on a `macos-15` runner.
3. The build uploads itself to TestFlight via the App Store Connect API.
4. You open the TestFlight app on your iPhone, install the build, test it.
5. When happy, promote to the App Store in App Store Connect — one click.

Nothing else needs a Mac. Your Windows PC stays your Windows PC.

## What you need before you start

- An **Apple Developer Program** account (the $99/yr one) — you already
  have it; the app is live in the App Store.
- The Reacti app already registered in **App Store Connect** with the
  bundle id **`com.reacti.app`** — already done; that's what the
  current store listing uses.
- Roughly 30 minutes the first time. Subsequent releases are
  `git tag` + wait.

## Six GitHub Actions secrets to create

The release workflow (`.github/workflows/ios-release.yml`) is committed
and waits for these. Add them at
`https://github.com/reacti25/reacti/settings/secrets/actions`.

| Secret name | What it is |
|---|---|
| `IOS_CERT_P12_BASE64` | Base64 of your iOS Distribution cert exported as `.p12` |
| `IOS_CERT_P12_PASSWORD` | The password you set when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 of the App Store provisioning profile (`.mobileprovision`) |
| `ASC_API_KEY_ID` | App Store Connect API key id (10-char) |
| `ASC_API_ISSUER_ID` | App Store Connect API issuer id (UUID) |
| `ASC_API_KEY_BASE64` | Base64 of the `.p8` API key file |

Below is exactly how to produce each one. **None of these steps need a
Mac** unless explicitly called out; everything can be done from
[developer.apple.com](https://developer.apple.com) and
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) in a
browser.

---

## Step 1 — App Store Connect API key (the upload credential)

The API key is what GitHub Actions uses to upload builds to TestFlight
instead of you typing your Apple ID password.

1. Open https://appstoreconnect.apple.com → **Users and Access** → **Integrations** → **App Store Connect API**.
2. Click **Generate API Key** (or "+"). Name it `reacti-ci`. **Access: Developer** is enough.
3. Click **Generate**.
4. **Download the `.p8` file immediately** — Apple only lets you do this once.
5. From the same screen, copy the **Key ID** (10 characters, e.g. `ABC123XYZ4`) and the **Issuer ID** (UUID at the top of the page).

Make the three secrets:

```sh
# On any machine with `base64`:
base64 -w 0 < AuthKey_ABC123XYZ4.p8        # paste into ASC_API_KEY_BASE64
```

- `ASC_API_KEY_ID`   ← the 10-char key id
- `ASC_API_ISSUER_ID` ← the UUID issuer id
- `ASC_API_KEY_BASE64` ← the base64 from above

Powershell equivalent:

```pwsh
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_ABC123XYZ4.p8"))
```

---

## Step 2 — iOS Distribution certificate (the signing credential)

The cert proves "this build comes from your Apple Developer account."

You almost certainly have one already, since your app is live in the
App Store — whoever built that initial release created it. Two paths:

### Path A: you (or your contractor) still have the .p12 export

If you have a `.p12` file saved from the original build:

```sh
base64 -w 0 < ios_distribution.p12         # paste into IOS_CERT_P12_BASE64
```

- `IOS_CERT_P12_BASE64` ← the base64 above
- `IOS_CERT_P12_PASSWORD` ← the password set when the .p12 was exported

### Path B: you need to create a fresh one (browser-only)

1. Generate a Certificate Signing Request (CSR) — needs a private key.
   On any OS with `openssl`:

   ```sh
   openssl genrsa -out reacti.key 2048
   openssl req -new -key reacti.key -out reacti.csr \
     -subj "/emailAddress=you@example.com/CN=Reacti iOS Distribution/C=US"
   ```

2. Open https://developer.apple.com/account/resources/certificates/list → **+** (Add).
3. Choose **Apple Distribution**. Upload `reacti.csr`. Download the
   resulting `reacti.cer`.
4. Bundle the `.cer` + private key into a `.p12`:

   ```sh
   # Convert .cer to PEM, then pack with the key into a .p12
   openssl x509 -in reacti.cer -inform DER -out reacti.pem -outform PEM
   openssl pkcs12 -export \
     -inkey reacti.key \
     -in reacti.pem \
     -out reacti.p12 \
     -passout pass:<choose-a-password>
   ```

5. `base64 -w 0 < reacti.p12` → `IOS_CERT_P12_BASE64`.
6. The chosen password → `IOS_CERT_P12_PASSWORD`.

---

## Step 3 — App Store provisioning profile

The profile binds the cert above to your specific bundle id
(`com.reacti.app`) and authorises App Store distribution.

1. Open https://developer.apple.com/account/resources/profiles/list → **+** (Add).
2. **App Store Connect** → Continue.
3. **App ID: `com.reacti.app`** → Continue.
4. **Certificate: the Apple Distribution cert from Step 2** → Continue.
5. **Name:** e.g. `Reacti App Store` (this is what goes into
   `app/ios/ExportOptions.plist` — see step 4 below).
6. Click **Generate**, then **Download**. You get a `.mobileprovision`.
7. Encode it:

   ```sh
   base64 -w 0 < Reacti_App_Store.mobileprovision      # → IOS_PROVISIONING_PROFILE_BASE64
   ```

---

## Step 4 — fill in the provisioning-profile *name* in ExportOptions.plist

Open `app/ios/ExportOptions.plist`, find this line:

```xml
<key>com.reacti.app</key>
<string>&lt;PROFILE_NAME&gt;</string>
```

Replace `<PROFILE_NAME>` with the exact **Name** you gave the profile
in step 3 (e.g. `Reacti App Store`). Commit and push that change.

---

## Step 5 — tag a release

```sh
# Match what's in pubspec.yaml `version:` (currently 1.0.9+10)
# Bump it before tagging if this is a new release.
git tag v1.0.10
git push origin v1.0.10
```

Watch the run at
`https://github.com/reacti25/reacti/actions/workflows/ios-release.yml`.

It will:

1. Build a signed release `.ipa`.
2. Upload it to TestFlight.

Total time: ~10–12 minutes.

---

## Step 6 — install from TestFlight on your iPhone

1. The build appears in App Store Connect → TestFlight tab → Builds
   after ~5 minutes of Apple processing (separate from the GitHub run).
2. Add yourself as an Internal Tester if you haven't.
3. Open the TestFlight app on your iPhone, install the new build.
4. Test the flows that matter — sign in, send a chat, receive a chat,
   the patent-flow blur/mark-viewed/reaction, group chat, social
   login.

When you're satisfied, in App Store Connect click **Distribute App** →
the build is submitted to App Store review.

---

## Troubleshooting

**`No identity found` during sign step.** The `.p12` password is
wrong, or the export didn't include the private key. Re-export from
Keychain Access with "My Certificates" view (not "Certificates"),
right-click → Export → Personal Information Exchange. Set a password,
re-base64.

**`No matching provisioning profile`.** The profile's bundle id
doesn't match `com.reacti.app`, or its embedded cert doesn't match
the `.p12` you uploaded. Re-create the profile (step 3) using the
same cert.

**`Could not find profile`** with the name from ExportOptions.plist.
The provisioning-profile **Name** in step 3 must match exactly. Edit
`ExportOptions.plist` to the actual name.

**`Authentication failed`** during upload. The API key id or issuer
id is wrong; double-check from App Store Connect → Integrations.

**Build succeeds, TestFlight rejects with "missing compliance"** or
similar. That's an App Store Connect setting — set Export Compliance
to "no encryption beyond standard exemptions" in the build's listing
in App Store Connect (one-time per release).

---

## How this fits

- `.github/workflows/flutter-ci.yml` already runs an unsigned iOS
  compile on every PR — catches breaks before they reach a release.
- `.github/workflows/ios-release.yml` is what runs on a `v*` tag and
  does the signed build + upload.
- The Android side has equivalent setup *to be done* — out of scope
  for this doc.
