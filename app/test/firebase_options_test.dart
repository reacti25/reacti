// Guards the staging Firebase iOS config. Staging push tokens are scoped to the
// com.reacti.app.staging bundle via a SEPARATE Firebase app (distinct appId)
// under the same reacti-app project. If the staging appId/bundle ever drifts to
// production's, the staging TestFlight app would silently grab prod push tokens.

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
}
