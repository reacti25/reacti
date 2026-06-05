// Unit tests for VerifySignupOtpRx — the reactive wrapper around the
// signup OTP-verification API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. Mirrors the rx_login pattern.
//
// VerifySignupOtpRx overrides handleSuccessWithReturn: a successful
// verification persists the auth token, login flag and user id to local
// storage (like LoginRx), so the success test uses the shared GetStorage
// fixture. The error handler only records errorMessage for a
// DioException, so a plain Exception cleanly skips that branch.

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/auth/data/rx_signup_verify/api.dart';
import 'package:reacti_app/features/auth/data/rx_signup_verify/rx.dart';
import 'package:reacti_app/features/auth/model/login_response.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// A fake [SignUpVerifyApi] that records the arguments it was called with
/// and always throws a preset error — exercises [VerifySignupOtpRx]'s
/// failure path without real HTTP. Uses `implements` so no access to the
/// api's private constructor is needed.
class _ThrowingSignUpVerifyApi implements SignUpVerifyApi {
  /// The error every [verifySignupOtp] call throws.
  final Object errorToThrow;

  /// How many times [verifySignupOtp] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent call.
  String? lastEmail;

  /// The `otp` passed to the most recent call.
  String? lastOtp;

  _ThrowingSignUpVerifyApi(this.errorToThrow);

  @override
  Future<LoginResponse> verifySignupOtp({
    required String otp,
    required String email,
  }) async {
    callCount++;
    lastEmail = email;
    lastOtp = otp;
    throw errorToThrow;
  }
}

/// A fake [SignUpVerifyApi] that returns a preset [LoginResponse] —
/// exercises [VerifySignupOtpRx]'s success path without real HTTP.
class _SucceedingSignUpVerifyApi implements SignUpVerifyApi {
  /// The response every [verifySignupOtp] call resolves with.
  final LoginResponse response;

  _SucceedingSignUpVerifyApi(this.response);

  @override
  Future<LoginResponse> verifySignupOtp({
    required String otp,
    required String email,
  }) async => response;
}

void main() {
  group('VerifySignupOtpRx', () {
    test(
      'verifySignupOtp() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingSignUpVerifyApi(error);
        final fetcher = BehaviorSubject<LoginResponse>();
        final rx = VerifySignupOtpRx(
          api: fake,
          empty: LoginResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.verifySignupOtp(
          otp: '123456',
          email: 'alice@example.com',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        expect(fake.lastOtp, '123456');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = VerifySignupOtpRx(
        empty: LoginResponse(),
        dataFetcher: BehaviorSubject<LoginResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(SignUpVerifyApi.instance));
    });

    test(
      'verifySignupOtp() persists the session and emits the response on success',
      () async {
        await initTestGetStorage();
        initTestSecureStorage();

        final response = LoginResponse(
          success: true,
          data: Data(id: 11, token: 'tok-signup'),
        );
        final fetcher = BehaviorSubject<LoginResponse>();
        final rx = VerifySignupOtpRx(
          api: _SucceedingSignUpVerifyApi(response),
          empty: LoginResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.verifySignupOtp(
          otp: '123456',
          email: 'a@b.com',
        );

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // The overridden success handler persists the session: the token to
        // the secure store, the flag and user id to GetStorage.
        expect(AuthTokenStore.instance.token, 'tok-signup');
        expect(appData.read(kKeyIsLoggedIn), true);
        expect(appData.read(kKeyUserId), 11);
      },
    );
  });
}
