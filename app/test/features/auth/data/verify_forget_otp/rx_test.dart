// Unit tests for VerifyForgetPassRx — the reactive wrapper around the
// forgot-password OTP-verification API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. Mirrors the rx_login pattern.
//
// VerifyForgetPassRx does NOT override handleSuccessWithReturn (the base
// class emits the `Map` on the stream), but its public method has an
// extra side effect: after a successful call it copies the response
// `token` into `resendToken` for the reset-password step. The error
// handler only does anything for a DioException, so a plain Exception
// cleanly skips the toast.

import 'package:reacti_app/features/auth/data/verify_forget_otp/api.dart';
import 'package:reacti_app/features/auth/data/verify_forget_otp/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [VerifyForgetPassApi] that records the arguments it was called
/// with and always throws a preset error — exercises
/// [VerifyForgetPassRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the api's private constructor is needed.
class _ThrowingVerifyForgetPassApi implements VerifyForgetPassApi {
  /// The error every [verifyForgetPass] call throws.
  final Object errorToThrow;

  /// How many times [verifyForgetPass] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent call.
  String? lastEmail;

  /// The `otp` passed to the most recent call.
  String? lastOtp;

  _ThrowingVerifyForgetPassApi(this.errorToThrow);

  @override
  Future<Map> verifyForgetPass({
    required String email,
    required String otp,
  }) async {
    callCount++;
    lastEmail = email;
    lastOtp = otp;
    throw errorToThrow;
  }
}

/// A fake [VerifyForgetPassApi] that returns a preset response map —
/// exercises [VerifyForgetPassRx]'s success path without real HTTP.
class _SucceedingVerifyForgetPassApi implements VerifyForgetPassApi {
  /// The map every [verifyForgetPass] call resolves with.
  final Map response;

  _SucceedingVerifyForgetPassApi(this.response);

  @override
  Future<Map> verifyForgetPass({
    required String email,
    required String otp,
  }) async => response;
}

void main() {
  group('VerifyForgetPassRx', () {
    test(
      'verifyForgetPass() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingVerifyForgetPassApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = VerifyForgetPassRx(
          api: fake,
          empty: {},
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.verifyForgetPass(
          email: 'alice@example.com',
          otp: '123456',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        expect(fake.lastOtp, '123456');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
        // The token is never assigned when the call fails.
        expect(rx.resendToken, isNull);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = VerifyForgetPassRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(VerifyForgetPassApi.instance));
    });

    test(
      'verifyForgetPass() emits the response and captures the reset token on success',
      () async {
        final response = {'success': true, 'token': 'reset-tok-xyz'};
        final fetcher = BehaviorSubject<Map>();
        final rx = VerifyForgetPassRx(
          api: _SucceedingVerifyForgetPassApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.verifyForgetPass(
          email: 'a@b.com',
          otp: '123456',
        );

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // The public method copies the response `token` into resendToken
        // so the reset-password step can authorize the change.
        expect(rx.resendToken, 'reset-tok-xyz');
      },
    );
  });
}
