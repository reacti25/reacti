// Unit tests for ForgetPassRx — the reactive wrapper around the
// forgot-password API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. Mirrors the rx_login pattern.
//
// ForgetPassRx does NOT override handleSuccessWithReturn, so success
// simply emits the decoded `Map` on the stream via the RxResponseInt
// base behaviour — no storage writes. The error handler only does
// anything for a DioException, so a plain Exception cleanly skips the
// toast.

import 'package:reacti_app/features/auth/data/rx_forget_pass/api.dart';
import 'package:reacti_app/features/auth/data/rx_forget_pass/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ForgetPassApi] that records the email it was called with and
/// always throws a preset error — exercises [ForgetPassRx]'s failure
/// path without real HTTP. Uses `implements` so no access to the api's
/// private constructor is needed.
class _ThrowingForgetPassApi implements ForgetPassApi {
  /// The error every [forgetPassword] call throws.
  final Object errorToThrow;

  /// How many times [forgetPassword] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent call.
  String? lastEmail;

  _ThrowingForgetPassApi(this.errorToThrow);

  @override
  Future<Map> forgetPassword({required String email}) async {
    callCount++;
    lastEmail = email;
    throw errorToThrow;
  }
}

/// A fake [ForgetPassApi] that returns a preset response map — exercises
/// [ForgetPassRx]'s success path without real HTTP.
class _SucceedingForgetPassApi implements ForgetPassApi {
  /// The map every [forgetPassword] call resolves with.
  final Map response;

  _SucceedingForgetPassApi(this.response);

  @override
  Future<Map> forgetPassword({required String email}) async => response;
}

void main() {
  group('ForgetPassRx', () {
    test(
      'forgetPassword() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingForgetPassApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = ForgetPassRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.forgetPassword(email: 'alice@example.com');

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ForgetPassRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(ForgetPassApi.instance));
    });

    test('forgetPassword() emits the response map on success', () async {
      final response = {'success': true, 'message': 'otp sent'};
      final fetcher = BehaviorSubject<Map>();
      final rx = ForgetPassRx(
        api: _SucceedingForgetPassApi(response),
        empty: {},
        dataFetcher: fetcher,
      );

      final result = await rx.forgetPassword(email: 'a@b.com');

      // The call reports success and the response reaches the stream.
      // ForgetPassRx does not override handleSuccessWithReturn, so the
      // base class just emits the map — there are no storage side effects.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });
  });
}
