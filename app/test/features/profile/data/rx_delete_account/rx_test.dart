// Unit tests for DeleteAccountRx — the reactive wrapper around the
// account-deletion API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. This file pins DeleteAccountRx's actual behaviour on
// both the error path and the success path.

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/features/profile/data/rx_delete_account/api.dart';
import 'package:achiar_expert_app/features/profile/data/rx_delete_account/rx.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// A fake [DeleteAccountApi] that always throws a preset error — lets us
/// exercise [DeleteAccountRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingDeleteAccountApi implements DeleteAccountApi {
  /// The error every [deleteAccount] call throws.
  final Object errorToThrow;

  /// How many times [deleteAccount] was invoked.
  int callCount = 0;

  _ThrowingDeleteAccountApi(this.errorToThrow);

  @override
  Future<Map> deleteAccount() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [DeleteAccountApi] that returns a preset [Map] — lets us
/// exercise [DeleteAccountRx]'s success path without real HTTP.
class _SucceedingDeleteAccountApi implements DeleteAccountApi {
  /// The response every [deleteAccount] call resolves with.
  final Map response;

  _SucceedingDeleteAccountApi(this.response);

  @override
  Future<Map> deleteAccount() async => response;
}

void main() {
  group('DeleteAccountRx', () {
    test(
      'deleteAccount() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingDeleteAccountApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = DeleteAccountRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.deleteAccount();

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = DeleteAccountRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(DeleteAccountApi.instance));
    });

    test(
      'deleteAccount() emits the response and re-asserts the logged-in flag on success',
      () async {
        await initTestGetStorage();

        final response = {'success': true, 'message': 'account deleted'};
        final fetcher = BehaviorSubject<Map>();
        final rx = DeleteAccountRx(
          api: _SucceedingDeleteAccountApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.deleteAccount();

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // handleSuccessWithReturn writes kKeyIsLoggedIn = true (current
        // behaviour — note the success handler does NOT clear the session).
        expect(appData.read(kKeyIsLoggedIn), true);
      },
    );
  });
}
