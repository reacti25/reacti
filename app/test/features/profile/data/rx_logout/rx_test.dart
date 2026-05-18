// Unit tests for LogoutRx — the reactive wrapper around the logout API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. This file pins LogoutRx's actual behaviour on both the
// error path and the success path.

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/features/profile/data/rx_logout/api.dart';
import 'package:achiar_expert_app/features/profile/data/rx_logout/rx.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// A fake [LogoutApi] that always throws a preset error — lets us
/// exercise [LogoutRx]'s failure path without real HTTP. Uses
/// `implements` so no access to LogoutApi's private constructor is needed.
class _ThrowingLogoutApi implements LogoutApi {
  /// The error every [userLogout] call throws.
  final Object errorToThrow;

  /// How many times [userLogout] was invoked.
  int callCount = 0;

  _ThrowingLogoutApi(this.errorToThrow);

  @override
  Future<Map> userLogout() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [LogoutApi] that returns a preset [Map] — lets us exercise
/// [LogoutRx]'s success path without real HTTP.
class _SucceedingLogoutApi implements LogoutApi {
  /// The response every [userLogout] call resolves with.
  final Map response;

  _SucceedingLogoutApi(this.response);

  @override
  Future<Map> userLogout() async => response;
}

void main() {
  group('LogoutRx', () {
    test(
      'userLogout() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingLogoutApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = LogoutRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.userLogout();

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = LogoutRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(LogoutApi.instance));
    });

    test(
      'userLogout() emits the response and re-asserts the logged-in flag on success',
      () async {
        await initTestGetStorage();

        final response = {'success': true, 'message': 'logged out'};
        final fetcher = BehaviorSubject<Map>();
        final rx = LogoutRx(
          api: _SucceedingLogoutApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.userLogout();

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
