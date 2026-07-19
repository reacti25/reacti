// Tests for saveAndRegisterFcmToken — the FCM token-refresh handler.
//
// FCM rotates tokens; without re-registering the rotated token the backend
// keeps pushing to a dead token and notifications silently stop until the next
// login. These pin: the token is always cached locally, and it is re-registered
// with the backend ONLY when there is a session to register it against (logged
// in + a stored device id), never while logged out.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/profile/data/rx_add_token/rx.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/notification_services.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

import '../support/test_storage.dart';

/// Records each backend re-registration so the test can assert whether — and
/// with what args — a rotated token was posted.
class _FakeAddTokenRx extends AddTokenRx {
  _FakeAddTokenRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  final calls = <({String deviceId, String token})>[];

  @override
  Future<bool> addToken({
    required String deviceId,
    required String token,
  }) async {
    calls.add((deviceId: deviceId, token: token));
    return true;
  }
}

void main() {
  late _FakeAddTokenRx fake;
  late AddTokenRx original;

  setUp(() async {
    await initTestGetStorage();
    await appData.erase();
    original = api_access.addTokenRx;
    fake = _FakeAddTokenRx();
    api_access.addTokenRx = fake;
  });

  tearDown(() => api_access.addTokenRx = original);

  test('caches the token locally regardless of session', () async {
    await saveAndRegisterFcmToken('new-token');

    expect(appData.read(kKeyFCMToken), 'new-token');
  });

  test(
    're-registers with the backend when logged in with a device id',
    () async {
      await appData.write(kKeyDeviceID, 'device-1');
      await appData.write(kKeyIsLoggedIn, true);

      await saveAndRegisterFcmToken('rotated-token');

      expect(fake.calls, hasLength(1));
      expect(fake.calls.single.deviceId, 'device-1');
      expect(fake.calls.single.token, 'rotated-token');
    },
  );

  test('does not hit the backend when logged out', () async {
    await appData.write(kKeyDeviceID, 'device-1');
    await appData.write(kKeyIsLoggedIn, false);

    await saveAndRegisterFcmToken('rotated-token');

    expect(fake.calls, isEmpty);
    expect(appData.read(kKeyFCMToken), 'rotated-token'); // still cached
  });

  test('does not hit the backend when there is no device id', () async {
    await appData.write(kKeyIsLoggedIn, true);

    await saveAndRegisterFcmToken('rotated-token');

    expect(fake.calls, isEmpty);
  });
}
