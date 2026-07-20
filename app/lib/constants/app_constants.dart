// ignore_for_file: constant_identifier_names

/// Namespace of regular-expression patterns used for input validation.
///
/// Grouped as static fields so forms validate against one canonical pattern.
final class AppRegExpText {
  /// Private constructor — this class is never instantiated.
  AppRegExpText._();
  // Regular Expression

  /// Loose email pattern used for quick field validation.
  static String kRegExpEmail =
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+";

  /// Phone-number pattern allowing optional country code and grouping.
  static String kRegExpPhone =
      // ignore: prefer_adjacent_string_concatenation
      "(\\+[0-9]+[\\- \\.]*)?(\\([0-9]+\\)[\\- \\.]*)?" +
      "([0-9][0-9\\- \\.]+[0-9])";

  /// Stricter RFC-style email pattern (also accepts bracketed IP hosts).
  static String patternMail =
      r"^(([^<>()[\]\\.,;:\s@\']+(\.[^<>()[\]\\.,;:\s@\']+)*)|(\'.+\'))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$";
}

/// Storage key for the persisted bearer access token.
const String kKeyAccessToken = "kKeyAccessToken";

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

/// Language code for English.
const String kKeyEnglish = 'en';

/// Language code for French.
const String kKeyFrench = 'fr';

/// Ordered list of supported language codes.
const List<String> kLanguagesKey = [kKeyEnglish, kKeyFrench];

/// Maps each supported language code to its display name.
const Map languages = <String, String>{
  kKeyEnglish: "English",
  kKeyFrench: "French",
};

/// Maps each supported language code to its associated country code.
const Map countriesCode = <String, String>{kKeyEnglish: "US", kKeyFrench: "FR"};
