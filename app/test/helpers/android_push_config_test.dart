// Pins the Android push wiring that no widget test can see (plan Step 6).
//
// Three places must name the same notification channel: the channel the app
// creates (kAndroidPushChannelId), the manifest's default channel (used when
// FCM draws a background push itself), and the backend's payload. If they
// drift apart, pushes quietly fall back to a low-importance channel: no banner,
// and nothing fails loudly. Reads the source files directly; the built-APK side
// is checked in CI (flutter-ci.yml).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/notification_services.dart';

void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  /// The android:value / android:resource of the meta-data named [name].
  String? metaData(String name) => RegExp(
    'android:name="${RegExp.escape(name)}"\\s+android:(?:value|resource)="([^"]+)"',
  ).firstMatch(manifest)?.group(1);

  test('manifest default channel matches the channel the app creates', () {
    expect(
      metaData('com.google.firebase.messaging.default_notification_channel_id'),
      kAndroidPushChannelId,
    );
  });

  test('manifest default icon is the silhouette the app uses', () {
    expect(
      metaData('com.google.firebase.messaging.default_notification_icon'),
      kAndroidPushIcon,
    );
  });

  test('the silhouette icon exists at every density', () {
    final name = kAndroidPushIcon.split('/').last;
    for (final dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final png = File('android/app/src/main/res/drawable-$dpi/$name.png');
      expect(png.existsSync(), isTrue, reason: '${png.path} is missing');
    }
  });

  test('the backend push payload names the same channel', () {
    final helper = File('../backend/app/Helpers/Helper.php').readAsStringSync();
    expect(helper, contains("'channel_id' => '$kAndroidPushChannelId'"));
  });
}
