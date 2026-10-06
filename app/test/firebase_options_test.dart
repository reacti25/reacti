// Guards the staging Firebase iOS config. Staging push tokens are scoped to the
// com.reacti.app.staging bundle via a SEPARATE Firebase app (distinct appId)
// under the same reacti-app project. If the staging appId/bundle ever drifts to
// production's, the staging TestFlight app would silently grab prod push tokens.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/firebase_options.dart';

void main() {
  test('staging iOS Firebase app is distinct from production', () {
    // A different Firebase app (its own appId) and the staging bundle id.
    expect(
      DefaultFirebaseOptions.iosStaging.appId,
      isNot(DefaultFirebaseOptions.ios.appId),
    );
    expect(
      DefaultFirebaseOptions.iosStaging.iosBundleId,
      'com.reacti.app.staging',
    );
    expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.reacti.app');
  });

  test('staging stays in the same Firebase project as production', () {
    // Same project + sender → the one backend service account can push to both.
    expect(
      DefaultFirebaseOptions.iosStaging.projectId,
      DefaultFirebaseOptions.ios.projectId,
    );
    expect(
      DefaultFirebaseOptions.iosStaging.messagingSenderId,
      DefaultFirebaseOptions.ios.messagingSenderId,
    );
  });

  test('staging Android Firebase app is distinct, same project', () {
    expect(
      DefaultFirebaseOptions.androidStaging.appId,
      isNot(DefaultFirebaseOptions.android.appId),
    );
    expect(
      DefaultFirebaseOptions.androidStaging.projectId,
      DefaultFirebaseOptions.android.projectId,
    );
    expect(
      DefaultFirebaseOptions.androidStaging.messagingSenderId,
      DefaultFirebaseOptions.android.messagingSenderId,
    );
  });

  test('Dart Android app ids match google-services.json for each package', () {
    // Firebase starts natively from google-services.json (picking the client
    // for the build's package) and again from Dart. If the two disagree, the
    // staging build would register push tokens under the wrong app.
    final json =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final appIdByPackage = {
      for (final c in json['client'] as List)
        c['client_info']['android_client_info']['package_name']:
            c['client_info']['mobilesdk_app_id'],
    };
    expect(
      appIdByPackage['com.reacti.app'],
      DefaultFirebaseOptions.android.appId,
    );
    expect(
      appIdByPackage['com.reacti.app.staging'],
      DefaultFirebaseOptions.androidStaging.appId,
    );
  });
}
