// Unit tests for ChangePasswordRx — the reactive wrapper around the
// password-change API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. This file pins ChangePasswordRx's actual behaviour on
// both the error path and the success path.
//
// Note: ChangePasswordRx does NOT override handleSuccessWithReturn, so
// the success path uses the base RxResponseInt implementation — it only
// pushes the response onto the stream and writes no storage.

import 'package:achiar_expert_app/features/change_password/data/rx_change_password/api.dart';
import 'package:achiar_expert_app/features/change_password/data/rx_change_password/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ChangePasswordApi] that records its arguments and always
/// throws a preset error — lets us exercise [ChangePasswordRx]'s failure
/// path without real HTTP. Uses `implements` so no access to the private
/// constructor is needed.
class _ThrowingChangePasswordApi implements ChangePasswordApi {
  /// The error every [changePassword] call throws.
  final Object errorToThrow;

  /// How many times [changePassword] was invoked.
  int callCount = 0;

  _ThrowingChangePasswordApi(this.errorToThrow);

  @override
  Future<Map> changePassword({
    required String oldPass,
    required String newPass,
    required String confNewPass,
  }) async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [ChangePasswordApi] that records its arguments and returns a
/// preset [Map] — lets us exercise [ChangePasswordRx]'s success path
/// without real HTTP.
class _SucceedingChangePasswordApi implements ChangePasswordApi {
  /// The response every [changePassword] call resolves with.
  final Map response;

  /// The `oldPass` passed to the most recent [changePassword] call.
  String? lastOldPass;

  /// The `newPass` passed to the most recent [changePassword] call.
  String? lastNewPass;

  /// The `confNewPass` passed to the most recent [changePassword] call.
  String? lastConfNewPass;

  _SucceedingChangePasswordApi(this.response);

  @override
  Future<Map> changePassword({
    required String oldPass,
    required String newPass,
    required String confNewPass,
  }) async {
    lastOldPass = oldPass;
    lastNewPass = newPass;
    lastConfNewPass = confNewPass;
    return response;
  }
}

void main() {
  group('ChangePasswordRx', () {
    test(
      'changePassword() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingChangePasswordApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = ChangePasswordRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.changePassword(
          oldPass: 'old',
          newPass: 'new',
          confNewPass: 'new',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ChangePasswordRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(ChangePasswordApi.instance));
    });

    test(
      'changePassword() forwards every argument and emits the response on success',
      () async {
        final response = {'success': true, 'message': 'password changed'};
        final fake = _SucceedingChangePasswordApi(response);
        final fetcher = BehaviorSubject<Map>();
        final rx = ChangePasswordRx(api: fake, empty: {}, dataFetcher: fetcher);

        final result = await rx.changePassword(
          oldPass: 'old',
          newPass: 'new',
          confNewPass: 'new',
        );

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // Every argument is forwarded verbatim to the api.
        expect(fake.lastOldPass, 'old');
        expect(fake.lastNewPass, 'new');
        expect(fake.lastConfNewPass, 'new');
        // ChangePasswordRx does not override handleSuccessWithReturn, so
        // the base RxResponseInt impl runs — no storage write to assert.
      },
    );
  });
}
