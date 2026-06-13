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

/// Storage key mirroring the server's silent-recording consent timestamp
/// (DG1). Absent/null means the user has not consented; the reaction feature
/// stays off for them. The server (`recording_consent_at`) is the source of
/// truth — this is a local mirror for fast synchronous checks at the capture
/// point.
const String kKeyRecordingConsentAt = "kKeyRecordingConsentAt";

/// Storage key for the user's last-known latitude.
const String KKeyUserCurrentLat = 'KKeyUserCurrentLat';

/// Storage key for the user's last-known longitude.
const String KKeyUserCurrentLng = 'KKeyUserCurrentLng';

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
