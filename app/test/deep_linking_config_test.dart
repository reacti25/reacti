// Regression guard: Flutter's built-in deep linking stays off on both
// platforms. Invite links are handled by app_links (InviteDeepLinks); with
// Flutter's own deep linking on, every invite link also pushes "/i/{code}" as
// a named route the app has none for, which throws (found by the Android
// device journey, integration_test/device_features_test.dart).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android turns Flutter deep linking off', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains(
        '<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />',
      ),
    );
  });

  test('iOS turns Flutter deep linking off', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      plist,
      matches(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')),
    );
  });
}
