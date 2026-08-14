import 'dart:io';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Validation pattern for email addresses used in auth/profile forms.
final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

/// Whole years elapsed from [dob] to [asOf] (default: now).
///
/// A birthday falling on [asOf] counts as reached, so someone turning
/// [kMinSignupAge] today is old enough. [asOf] exists so tests can pin
/// "today" instead of depending on the day they run.
int ageInYears(DateTime dob, {DateTime? asOf}) {
  final today = asOf ?? DateTime.now();
  var age = today.year - dob.year;
  final hadBirthdayThisYear =
      today.month > dob.month ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}

/// Whether [dob] clears the signup age gate ([kMinSignupAge]).
///
/// Client-side courtesy only: the backend's `config('reacti.min_age')` rule
/// is the real gate, so a caller that skips this still gets refused.
bool isOldEnoughToSignUp(DateTime dob, {DateTime? asOf}) =>
    ageInYears(dob, asOf: asOf) >= kMinSignupAge;

/// Masks an email for display, keeping only the first character and the domain.
///
/// `achia.rosin19@gmail.com` → `a•••@gmail.com`. Returns the input unchanged
/// when it has no `@` or an empty local part, so callers never crash on
/// malformed input.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 1) return email; // no '@', or starts with '@' — nothing safe to mask
  return '${email[0]}•••${email.substring(at)}';
}

/// Seeds first-run default values into [appData] and captures the device ID.
///
/// Initialises the logged-in and first-time flags only if absent (so existing
/// state is preserved across restarts) and stores the platform-specific
/// device identifier. The trailing delay paces the splash screen.
Future<void> setInitValue() async {
  await appData.writeIfNull(kKeyIsLoggedIn, false);
  await appData.writeIfNull(kKeyIsFirstTime, true);

  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    var iosDeviceInfo = await deviceInfo.iosInfo;
    appData.writeIfNull(kKeyDeviceID, iosDeviceInfo.identifierForVendor);
  } else if (Platform.isAndroid) {
    var androidDeviceInfo = await deviceInfo.androidInfo;
    appData.writeIfNull(kKeyDeviceID, androidDeviceInfo.id);
  }
  // (Removed a hardcoded 3-second Future.delayed that padded every cold start
  // purely to keep the splash visible — the splash now shows only as long as
  // real initialization takes.)
}

/// Applies the app's global system-UI chrome and orientation preferences.
///
/// Makes the status bar transparent with dark icons and locks the app to
/// portrait orientations. Intended to run once during app bootstrap.
void rotation() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
