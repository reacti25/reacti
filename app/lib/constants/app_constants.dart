// ignore_for_file: constant_identifier_names

/// Storage key for the boolean logged-in flag.
const String kKeyIsLoggedIn = "kKeyIsLoggedIn";

/// Storage key for the current user's ID.
const String kKeyUserId = "kKeyUserId";

/// Storage key for the device identifier.
const String kKeyDeviceID = "kKeyDeviceID";

/// Storage key for the Firebase Cloud Messaging token.
const String kKeyFCMToken = "kKeyFCMToken";

/// Storage key for the first-launch flag (drives onboarding).
const String kKeyIsFirstTime = "kKeyIsFirstTime";

/// Storage key for the "skipped contacts" flag. When `true`, the user tapped
/// "Not now" on the contacts priming prompt, so we don't auto-prompt again; the
/// manual "find friends" action stays available.
const String kKeyContactsSkipped = "kKeyContactsSkipped";

/// Storage key for the one-time demo Reacti. When `true`, the user has already
/// seen the practice reaction, so it never re-fires (any first-timer sees it
/// once). See `features/demo/`.
const String kKeyDemoSeen = "kKeyDemoSeen";

/// Storage key for the one-time camera/mic soft-ask primer. When `true`, the
/// friendly "we need camera + mic" primer has been shown once; subsequent uses
/// go straight to the OS/permission state. Shared by the demo and the first
/// real Reacti open (Feature 8c).
const String kKeyCamMicPrimerShown = "kKeyCamMicPrimerShown";

/// Storage key for the set (JSON list) of contact identifiers the user has
/// invited via the share sheet, so their row stays "Invited" across reopens
/// (Feature 5).
const String kKeyInvitedContacts = "kKeyInvitedContacts";

/// Storage key for the reciprocal "read receipts" preference. Absent or `true`
/// = on (the default); when `false` the client suppresses rendering "seen" and
/// the server withholds the user's outgoing seen signal. Mirrored from the
/// profile so widgets can read it synchronously.
const String kKeyReadReceipts = "kKeyReadReceipts";

/// Storage key for the "sounds & haptics" preference. Absent or `true` = on
/// (the default); `false` disables the send/receive haptic feedback. Read into
/// [FeedbackService] at startup and updated live from the settings toggle.
const String kKeySoundHapticsEnabled = "kKeySoundHapticsEnabled";

/// Storage key for the analytics opt-out flag. When `true`, the user has opted
/// out of anonymous usage analytics and NO events are emitted (the
/// [AnalyticsService] and Sentry both honour it). Absent/`false` = opted in.
const String kKeyAnalyticsOptOut = "kKeyAnalyticsOptOut";

/// Storage key for the chosen appearance. Holds a [ThemeMode] name
/// (`system`/`light`/`dark`); absent = `system` (follow the OS).
const String kKeyThemeMode = "kKeyThemeMode";

/// Storage key marking that the one-time first-run appearance picker has been
/// shown (whether the user chose or skipped). Absent/`false` = not yet asked.
const String kKeyAppearanceAsked = "kKeyAppearanceAsked";

/// Storage key set on the sign-up verification success path so the first entry
/// to the app knows to offer the appearance picker (returning logins don't set
/// it, so they never see it). Consumed (cleared) once the prompt is shown.
const String kKeyJustSignedUp = "kKeyJustSignedUp";

/// Set once the first-run "how to use Reacti" tour has been completed or
/// skipped, so it never auto-fires again. Replay lives on the Profile screen.
const String kKeyTourSeen = "kKeyTourSeen";

/// Set once the just-in-time "Invite friends" coach mark has been shown.
const String kKeyTourInviteSeen = "kKeyTourInviteSeen";

/// Set once the just-in-time composer-attach coach mark has been shown.
const String kKeyTourAttachSeen = "kKeyTourAttachSeen";

/// Shortest username query the server will answer.
///
/// Mirrors `UserService::MIN_USERNAME_SEARCH`, which is the real gate — this
/// copy exists only so the search screen can explain why a shorter query
/// returns nobody, instead of looking broken.
const int kMinUsernameSearch = 3;

/// ISO-8601 timestamp of the very first launch on this install.
///
/// The clock time-to-value is measured from. The app cannot see the moment of
/// download (only App Store Connect has that), so first launch is the earliest
/// point it can honestly start counting.
const String kKeyFirstLaunchAt = "kKeyFirstLaunchAt";

/// Names of the activation milestones already reported, so each fires once.
const String kKeyActivationMilestones = "kKeyActivationMilestones";

/// Set once the "send a request and wait" coach mark has been shown.
const String kKeyTourSendRequestSeen = "kKeyTourSendRequestSeen";

/// Set once the "add your first friend" coach mark has been shown.
const String kKeyTourAddFriendSeen = "kKeyTourAddFriendSeen";

/// Set once the "open a chat" coach mark on the first chat row has been shown.
const String kKeyTourFirstChatSeen = "kKeyTourFirstChatSeen";

/// Set once the coach mark on the user's own first sent media has been shown.
const String kKeyTourSentMediaSeen = "kKeyTourSentMediaSeen";

/// Set once the coach mark on the first sealed media received has been shown.
const String kKeyTourSealedSeen = "kKeyTourSealedSeen";

/// Whether App Lock is on. Absent means OFF — a security feature nobody asked
/// for is a lockout waiting to happen.
const String kKeyAppLockEnabled = "kKeyAppLockEnabled";

/// Which [AppLockDelay] to use, stored by its `name`.
const String kKeyAppLockDelay = "kKeyAppLockDelay";

/// Prefix for the last-reported answer to each OS permission dialog, keyed
/// `kKeyPermissionReported:<permission>`.
///
/// Only a CHANGE is worth an analytics event: the notification permission is
/// re-requested on every launch and returns the standing answer without
/// showing a dialog, so reporting it every time would be the app's chattiest
/// event and say nothing new.
const String kKeyPermissionReported = "kKeyPermissionReported";

/// Youngest age that may hold a Reacti account, in years.
///
/// Mirrors `config('reacti.min_age')` on the backend, which is the actual
/// gate — this copy only drives client-side validation and copy so the user
/// gets an inline error instead of a round-trip 422. If the server value
/// changes, change this too.
const int kMinSignupAge = 16;
