// Unit tests for MakeGroupAdminRx — the reactive wrapper around the
// "make admin" API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Covers the error path, the success path and the singleton
// default.

import 'package:achiar_expert_app/features/group_details/data/rx_make_admin/api.dart';
import 'package:achiar_expert_app/features/group_details/data/rx_make_admin/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [MakeGroupAdminApi] that always throws a preset error — lets us
/// exercise [MakeGroupAdminRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingMakeGroupAdminApi implements MakeGroupAdminApi {
  /// The error every [makeGroupAdmin] call throws.
  final Object errorToThrow;

  /// How many times [makeGroupAdmin] was invoked.
  int callCount = 0;

  /// The `groupId` passed to the most recent [makeGroupAdmin] call.
  int? lastGroupId;

  /// The `userId` passed to the most recent [makeGroupAdmin] call.
  int? lastUserId;

  _ThrowingMakeGroupAdminApi(this.errorToThrow);

  @override
  Future<Map> makeGroupAdmin({
    required int groupId,
    required int userId,
  }) async {
    callCount++;
    lastGroupId = groupId;
    lastUserId = userId;
    throw errorToThrow;
  }
}

/// A fake [MakeGroupAdminApi] that returns a preset map — lets us
/// exercise [MakeGroupAdminRx]'s success path without real HTTP.
class _SucceedingMakeGroupAdminApi implements MakeGroupAdminApi {
  /// The response every [makeGroupAdmin] call resolves with.
  final Map response;

  _SucceedingMakeGroupAdminApi(this.response);

  @override
  Future<Map> makeGroupAdmin({
    required int groupId,
    required int userId,
  }) async =>
      response;
}

void main() {
  group('MakeGroupAdminRx', () {
    test(
      'makeGroupAdmin() delegates to the injected api and reports failure '
      'on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingMakeGroupAdminApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = MakeGroupAdminRx(
          api: fake,
          empty: {},
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.makeGroupAdmin(groupId: 3, userId: 8);

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastGroupId, 3);
        expect(fake.lastUserId, 8);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'makeGroupAdmin() emits the response and returns true on success',
      () async {
        final response = {'success': true, 'message': 'promoted'};
        final fetcher = BehaviorSubject<Map>();
        final rx = MakeGroupAdminRx(
          api: _SucceedingMakeGroupAdminApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.makeGroupAdmin(groupId: 3, userId: 8);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(rx.getGroupMediaStream.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = MakeGroupAdminRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(MakeGroupAdminApi.instance));
    });
  });
}
