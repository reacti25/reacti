import 'dart:io';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Validation pattern for email addresses used in auth/profile forms.
final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

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
