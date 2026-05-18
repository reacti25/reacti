// Unit tests for AddTokenRx — the reactive wrapper around the
// push-token registration API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. This file pins AddTokenRx's actual behaviour on both
// the error path and the success path.

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/features/profile/data/rx_add_token/api.dart';
import 'package:achiar_expert_app/features/profile/data/rx_add_token/rx.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// A fake [AddTokenApi] that records its arguments and always throws a
/// preset error — lets us exercise [AddTokenRx]'s failure path without
/// real HTTP. Uses `implements` so no access to the private constructor
/// is needed.
class _ThrowingAddTokenApi implements AddTokenApi {
  /// The error every [addToken] call throws.
  final Object errorToThrow;

  /// How many times [addToken] was invoked.
  int callCount = 0;

  /// The `deviceId` passed to the most recent [addToken] call.
  String? lastDeviceId;

  /// The `token` passed to the most recent [addToken] call.
  String? lastToken;

  _ThrowingAddTokenApi(this.errorToThrow);

  @override
  Future<Map> addToken({
    required String deviceId,
    required String token,
  }) async {
    callCount++;
    lastDeviceId = deviceId;
    lastToken = token;
    throw errorToThrow;
  }
}

/// A fake [AddTokenApi] that returns a preset [Map] — lets us exercise
/// [AddTokenRx]'s success path without real HTTP.
class _SucceedingAddTokenApi implements AddTokenApi {
  /// The response every [addToken] call resolves with.
  final Map response;

  _SucceedingAddTokenApi(this.response);

  @override
  Future<Map> addToken({
    required String deviceId,
    required String token,
  }) async =>
      response;
}

void main() {
  group('AddTokenRx', () {
    test(
      'addToken() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingAddTokenApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = AddTokenRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.addToken(
          deviceId: 'device-1',
          token: 'fcm-tok',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastDeviceId, 'device-1');
        expect(fake.lastToken, 'fcm-tok');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = AddTokenRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(AddTokenApi.instance));
    });

    test(
      'addToken() emits the response and re-asserts the logged-in flag on success',
      () async {
        await initTestGetStorage();

        final response = {'success': true, 'message': 'token saved'};
        final fetcher = BehaviorSubject<Map>();
        final rx = AddTokenRx(
          api: _SucceedingAddTokenApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.addToken(
          deviceId: 'device-1',
          token: 'fcm-tok',
        );

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // handleSuccessWithReturn writes kKeyIsLoggedIn = true (current
        // behaviour).
        expect(appData.read(kKeyIsLoggedIn), true);
      },
    );
  });
}
