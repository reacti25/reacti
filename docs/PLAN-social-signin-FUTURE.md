# FUTURE: Sign in with Google / Apple

**Status:** to do later. Not scheduled. Decided by Achia on 2026-10-25.

## Where things stand

- The app has only ever had email sign-up with a code (OTP). No app version
  ever showed a Google or Apple button.
- The backend had an unused leftover from the original dev team:
  `POST /api/social/signin/{provider}` (Google only, via `laravel/socialite`)
  and an admin page that wrote Google keys into `.env`. It was removed in
  PR "chore(backend): remove the unused Google/Apple sign-in" so nothing
  half-built stays live. The `users.google_id` / `users.apple_id` columns
  were kept (no migration).
- To see the removed code: `git log --all -- backend/app/Services/SocialAuthService.php`,
  then `git show <commit>^:backend/app/Services/SocialAuthService.php`.

## What doing it properly needs

1. **Apple rule:** if the iOS app offers Google sign-in, Apple requires
   "Sign in with Apple" too (App Store guideline 4.8). Plan both together.
2. **App side:** `sign_in_with_apple` + `google_sign_in` packages, buttons on
   the login and sign-up screens, Apple capability in Xcode, Google OAuth
   client ids per platform (staging and prod apps have separate bundle ids).
3. **Backend side:** verify the provider's ID token server-side, then find or
   create the user. New social accounts must still pass the **16+ age gate**
   (ask birthdate) and get a **username**, like email sign-ups.
4. **Account linking:** a person who already signed up by email and then taps
   "Sign in with Google" with the same address must land in the same account,
   not a duplicate.
5. **Apple "hide my email":** Apple may give a relay address; the account must
   work without a real email.
6. **Delete Account** must also revoke the Apple token (Apple requires it).
7. **Privacy policy:** list Google and Apple as sign-in providers.
8. Tests for each path, then a staging build for Achia before any release.
