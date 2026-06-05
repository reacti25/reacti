// Unit tests for LoginRx — the reactive wrapper around the login API.
//
// Pattern-setter for FP1 of the frontend refactor: the rx_* data
// sources are being made injectable (constructor-inject the api,
// defaulting to the singleton) so their logic can be unit-tested with
// a fake api instead of real HTTP. This file proves that pattern on
// rx_login, covering both the error path and the success path (the
// latter via the shared GetStorage fixture in test/support/).

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/auth/data/rx_login/api.dart';
import 'package:reacti_app/features/auth/data/rx_login/rx.dart';
import 'package:reacti_app/features/auth/model/login_response.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// A fake [LoginApi] that records the credentials it was called with and
/// always throws a preset error — lets us exercise [LoginRx]'s failure
/// path without real HTTP. Uses `implements` so no access to LoginApi's
/// private constructor is needed.
class _ThrowingLoginApi implements LoginApi {
  /// The error every [login] call throws.
  final Object errorToThrow;

  /// How many times [login] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent [login] call.
  String? lastEmail;

  /// The `password` passed to the most recent [login] call.
  String? lastPassword;

  _ThrowingLoginApi(this.errorToThrow);

  @override
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    callCount++;
    lastEmail = email;
    lastPassword = password;
    throw errorToThrow;
  }
}

/// A fake [LoginApi] that returns a preset [LoginResponse] — lets us
/// exercise [LoginRx]'s success path without real HTTP.
class _SucceedingLoginApi implements LoginApi {
  /// The response every [login] call resolves with.
  final LoginResponse response;

  _SucceedingLoginApi(this.response);

  @override
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async => response;
}

void main() {
  group('LoginRx', () {
    test(
      'login() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingLoginApi(error);
        final fetcher = BehaviorSubject<LoginResponse>();
        final rx = LoginRx(
          api: fake,
          empty: LoginResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.login(
          email: 'alice@example.com',
          password: 'secret',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        expect(fake.lastPassword, 'secret');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = LoginRx(
        empty: LoginResponse(),
        dataFetcher: BehaviorSubject<LoginResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(LoginApi.instance));
    });

    test(
      'login() persists the session and emits the response on success',
      () async {
        await initTestGetStorage();
        initTestSecureStorage();

        final response = LoginResponse(
          success: true,
          data: Data(id: 7, token: 'tok-abc'),
        );
        final fetcher = BehaviorSubject<LoginResponse>();
        final rx = LoginRx(
          api: _SucceedingLoginApi(response),
          empty: LoginResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.login(email: 'a@b.com', password: 'pw');

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // The token is persisted to the secure store; the rest to GetStorage.
        expect(AuthTokenStore.instance.token, 'tok-abc');
        expect(appData.read(kKeyIsLoggedIn), true);
        expect(appData.read(kKeyUserId), 7);
      },
    );
  });
}
