// Unit tests for ResetPasswordRx — the reactive wrapper around the
// password-reset API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. Mirrors the rx_login pattern.
//
// ResetPasswordRx does NOT override handleSuccessWithReturn, so success
// simply emits the decoded `Map` on the stream via the RxResponseInt
// base behaviour — no storage writes. The error handler only does
// anything for a DioException, so a plain Exception cleanly skips the
// toast.

import 'package:achiar_expert_app/features/auth/data/reset_pass/api.dart';
import 'package:achiar_expert_app/features/auth/data/reset_pass/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ResetPasswordApi] that records the arguments it was called
/// with and always throws a preset error — exercises [ResetPasswordRx]'s
/// failure path without real HTTP. Uses `implements` so no access to the
/// api's private constructor is needed.
class _ThrowingResetPasswordApi implements ResetPasswordApi {
  /// The error every [resetPassword] call throws.
  final Object errorToThrow;

  /// How many times [resetPassword] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent call.
  String? lastEmail;

  /// The `token` passed to the most recent call.
  String? lastToken;

  _ThrowingResetPasswordApi(this.errorToThrow);

  @override
  Future<Map> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confPass,
  }) async {
    callCount++;
    lastEmail = email;
    lastToken = token;
    throw errorToThrow;
  }
}

/// A fake [ResetPasswordApi] that returns a preset response map —
/// exercises [ResetPasswordRx]'s success path without real HTTP.
class _SucceedingResetPasswordApi implements ResetPasswordApi {
  /// The map every [resetPassword] call resolves with.
  final Map response;

  _SucceedingResetPasswordApi(this.response);

  @override
  Future<Map> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confPass,
  }) async =>
      response;
}

void main() {
  group('ResetPasswordRx', () {
    test(
      'resetPassword() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingResetPasswordApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = ResetPasswordRx(
          api: fake,
          empty: {},
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.resetPassword(
          email: 'alice@example.com',
          token: 'reset-tok',
          password: 'newpass',
          confPass: 'newpass',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        expect(fake.lastToken, 'reset-tok');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ResetPasswordRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(ResetPasswordApi.instance));
    });

    test('resetPassword() emits the response map on success', () async {
      final response = {'success': true, 'message': 'password updated'};
      final fetcher = BehaviorSubject<Map>();
      final rx = ResetPasswordRx(
        api: _SucceedingResetPasswordApi(response),
        empty: {},
        dataFetcher: fetcher,
      );

      final result = await rx.resetPassword(
        email: 'a@b.com',
        token: 'reset-tok',
        password: 'newpass',
        confPass: 'newpass',
      );

      // The call reports success and the response reaches the stream.
      // ResetPasswordRx does not override handleSuccessWithReturn, so the
      // base class just emits the map — there are no storage side effects.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });
  });
}
