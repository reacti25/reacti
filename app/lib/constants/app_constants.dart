// ignore_for_file: constant_identifier_names

final class AppRegExpText {
  AppRegExpText._();
  // Regular Expression
  static String kRegExpEmail =
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+";
  static String kRegExpPhone =
      // ignore: prefer_adjacent_string_concatenation
      "(\\+[0-9]+[\\- \\.]*)?(\\([0-9]+\\)[\\- \\.]*)?" +
      "([0-9][0-9\\- \\.]+[0-9])";

  static String patternMail =
      r"^(([^<>()[\]\\.,;:\s@\']+(\.[^<>()[\]\\.,;:\s@\']+)*)|(\'.+\'))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$";
}

const String kKeyAccessToken = "kKeyAccessToken";
const String kKeyIsLoggedIn = "kKeyIsLoggedIn";
const String kKeyUserId = "kKeyUserId";
const String kKeyDeviceID = "kKeyDeviceID";
const String kKeyFCMToken = "kKeyFCMToken";
const String kKeyIsFirstTime = "kKeyIsFirstTime";
const String KKeyUserCurrentLat = 'KKeyUserCurrentLat';
const String KKeyUserCurrentLng = 'KKeyUserCurrentLng';

const String kKeyEnglish = 'en';
const String kKeyFrench = 'fr';

const List<String> kLanguagesKey = [kKeyEnglish, kKeyFrench];
const Map languages = <String, String>{
  kKeyEnglish: "English",
  kKeyFrench: "French",
};

const Map countriesCode = <String, String>{kKeyEnglish: "US", kKeyFrench: "FR"};
