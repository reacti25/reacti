// Unit tests for RemoveMemberRx — the reactive wrapper around the
// "remove member" API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Covers the error path, the success path and the singleton
// default.

import 'package:reacti_app/features/group_details/data/rx_remove_member/api.dart';
import 'package:reacti_app/features/group_details/data/rx_remove_member/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [RemoveMemberApi] that always throws a preset error — lets us
/// exercise [RemoveMemberRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingRemoveMemberApi implements RemoveMemberApi {
  /// The error every [removeMember] call throws.
  final Object errorToThrow;

  /// How many times [removeMember] was invoked.
  int callCount = 0;

  /// The `groupId` passed to the most recent [removeMember] call.
  int? lastGroupId;

  /// The `userId` passed to the most recent [removeMember] call.
  int? lastUserId;

  _ThrowingRemoveMemberApi(this.errorToThrow);

  @override
  Future<Map> removeMember({required int groupId, required int userId}) async {
    callCount++;
    lastGroupId = groupId;
    lastUserId = userId;
    throw errorToThrow;
  }
}

/// A fake [RemoveMemberApi] that returns a preset map — lets us
/// exercise [RemoveMemberRx]'s success path without real HTTP.
class _SucceedingRemoveMemberApi implements RemoveMemberApi {
  /// The response every [removeMember] call resolves with.
  final Map response;

  _SucceedingRemoveMemberApi(this.response);

  @override
  Future<Map> removeMember({required int groupId, required int userId}) async =>
      response;
}

void main() {
  group('RemoveMemberRx', () {
    test('removeMember() delegates to the injected api and reports failure '
        'on a thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingRemoveMemberApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = RemoveMemberRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.removeMember(groupId: 5, userId: 11);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastGroupId, 5);
      expect(fake.lastUserId, 11);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test(
      'removeMember() emits the response and returns true on success',
      () async {
        final response = {'success': true, 'message': 'removed'};
        final fetcher = BehaviorSubject<Map>();
        final rx = RemoveMemberRx(
          api: _SucceedingRemoveMemberApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.removeMember(groupId: 5, userId: 11);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(rx.getFileData.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = RemoveMemberRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(RemoveMemberApi.instance));
    });
  });
}
