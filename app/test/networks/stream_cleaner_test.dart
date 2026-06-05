// Unit tests for totalDataClean — the session-clear used on logout
// and on a 401 from the API.
//
// Pre-fix, this function only set kKeyIsLoggedIn=false and left every
// other session key (access token, user id, FCM token) in storage, so
// the "logged-out" user still had a working bearer token until the
// app restarted. The fix erases those keys and rebuilds the Dio
// client unauthenticated; these tests pin that behaviour.

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:reacti_app/networks/dio/dio.dart';
import 'package:reacti_app/networks/stream_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_storage.dart';

void main() {
  setUp(() async {
    await initTestGetStorage();
    // Reset the secure-token store to a fresh, empty in-memory backend.
    initTestSecureStorage();
    // Each test starts from a clean storage so per-test asserts are
    // independent.
    await appData.erase();
    // Ensure the Dio client exists so totalDataClean's rebuild call
    // has a baseline to replace.
    DioSingleton.instance.create();
  });

  test('totalDataClean erases the access token', () async {
    await AuthTokenStore.instance.save('old-token');

    await totalDataClean();

    expect(AuthTokenStore.instance.token, isNull);
  });

  test('totalDataClean erases the user id', () async {
    await appData.write(kKeyUserId, 42);

    await totalDataClean();

    expect(appData.read(kKeyUserId), isNull);
  });

  test('totalDataClean erases the FCM token', () async {
    await appData.write(kKeyFCMToken, 'old-fcm');

    await totalDataClean();

    expect(appData.read(kKeyFCMToken), isNull);
  });

  test('totalDataClean sets kKeyIsLoggedIn to false', () async {
    await appData.write(kKeyIsLoggedIn, true);

    await totalDataClean();

    expect(appData.read(kKeyIsLoggedIn), isFalse);
  });

  test(
    'totalDataClean rebuilds the Dio client without the bearer header',
    () async {
      // Simulate a logged-in client carrying a stored bearer token.
      DioSingleton.instance.update('stale-token');
      expect(
        DioSingleton.instance.dio.options.headers['Authorization'],
        contains('stale-token'),
      );

      await totalDataClean();

      expect(
        DioSingleton.instance.dio.options.headers['Authorization'],
        isNull,
      );
    },
  );
}
