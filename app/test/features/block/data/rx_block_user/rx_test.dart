// Unit tests for BlockUserRx — the reactive wrapper around the block API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins BlockUserRx's actual behaviour on both the error
// path and the success path.

import 'package:achiar_expert_app/features/block/data/rx_block_user/api.dart';
import 'package:achiar_expert_app/features/block/data/rx_block_user/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [BlockUserApi] that records the id it was called with and always
/// throws a preset error — lets us exercise [BlockUserRx]'s failure path
/// without real HTTP. Uses `implements` so no access to BlockUserApi's
/// private constructor is needed.
class _ThrowingBlockUserApi implements BlockUserApi {
  /// The error every [blockUser] call throws.
  final Object errorToThrow;

  /// How many times [blockUser] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [blockUser] call.
  int? lastId;

  _ThrowingBlockUserApi(this.errorToThrow);

  @override
  Future<Map> blockUser({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [BlockUserApi] that returns a preset [Map] — lets us exercise
/// [BlockUserRx]'s success path without real HTTP.
class _SucceedingBlockUserApi implements BlockUserApi {
  /// The response every [blockUser] call resolves with.
  final Map response;

  _SucceedingBlockUserApi(this.response);

  @override
  Future<Map> blockUser({required int id}) async => response;
}

void main() {
  group('BlockUserRx', () {
    test('blockUser() delegates to the injected api and reports failure on a '
        'thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingBlockUserApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = BlockUserRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.blockUser(id: 42);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastId, 42);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('blockUser() emits the response and reports success', () async {
      final response = {'success': true, 'message': 'User blocked'};
      final fetcher = BehaviorSubject<Map>();
      final rx = BlockUserRx(
        api: _SucceedingBlockUserApi(response),
        empty: {},
        dataFetcher: fetcher,
      );

      final result = await rx.blockUser(id: 7);

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = BlockUserRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(BlockUserApi.instance));
    });
  });
}
