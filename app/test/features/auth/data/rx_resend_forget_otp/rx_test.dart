// Unit tests for ResendForgetOtpRx — the reactive wrapper around the
// resend-forgot-password-OTP API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. Mirrors the rx_login pattern.
//
// ResendForgetOtpRx does NOT override handleSuccessWithReturn, so
// success simply emits the decoded `Map` on the stream via the
// RxResponseInt base behaviour — no storage writes. The error handler
// only does anything for a DioException, so a plain Exception cleanly
// skips the toast.

import 'package:achiar_expert_app/features/auth/data/rx_resend_forget_otp/api.dart';
import 'package:achiar_expert_app/features/auth/data/rx_resend_forget_otp/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ResendForgetOtpApi] that records the email it was called with
/// and always throws a preset error — exercises [ResendForgetOtpRx]'s
/// failure path without real HTTP. Uses `implements` so no access to the
/// api's private constructor is needed.
class _ThrowingResendForgetOtpApi implements ResendForgetOtpApi {
  /// The error every [resendForgetOtp] call throws.
  final Object errorToThrow;

  /// How many times [resendForgetOtp] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent call.
  String? lastEmail;

  _ThrowingResendForgetOtpApi(this.errorToThrow);

  @override
  Future<Map> resendForgetOtp({required String email}) async {
    callCount++;
    lastEmail = email;
    throw errorToThrow;
  }
}

/// A fake [ResendForgetOtpApi] that returns a preset response map —
/// exercises [ResendForgetOtpRx]'s success path without real HTTP.
class _SucceedingResendForgetOtpApi implements ResendForgetOtpApi {
  /// The map every [resendForgetOtp] call resolves with.
  final Map response;

  _SucceedingResendForgetOtpApi(this.response);

  @override
  Future<Map> resendForgetOtp({required String email}) async => response;
}

void main() {
  group('ResendForgetOtpRx', () {
    test(
      'resendForgetOtp() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingResendForgetOtpApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = ResendForgetOtpRx(
          api: fake,
          empty: {},
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.resendForgetOtp(email: 'alice@example.com');

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ResendForgetOtpRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(ResendForgetOtpApi.instance));
    });

    test('resendForgetOtp() emits the response map on success', () async {
      final response = {'success': true, 'message': 'otp resent'};
      final fetcher = BehaviorSubject<Map>();
      final rx = ResendForgetOtpRx(
        api: _SucceedingResendForgetOtpApi(response),
        empty: {},
        dataFetcher: fetcher,
      );

      final result = await rx.resendForgetOtp(email: 'a@b.com');

      // The call reports success and the response reaches the stream.
      // ResendForgetOtpRx does not override handleSuccessWithReturn, so
      // the base class just emits the map — no storage side effects.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });
  });
}
