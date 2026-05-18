// Unit tests for GetFriendListRx — the reactive wrapper around the
// get-friend-list API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton) so
// their logic can be unit-tested with a fake api instead of real HTTP.
// Covers the error path and the success path, plus the singleton default.

import 'package:achiar_expert_app/features/friends/data/rx_get_friend_list/api.dart';
import 'package:achiar_expert_app/features/friends/data/rx_get_friend_list/rx.dart';
import 'package:achiar_expert_app/features/friends/model/friend_list_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetFriendListApi] that always throws a preset error — exercises
/// [GetFriendListRx]'s failure path without real HTTP. Uses `implements` so
/// no access to the api's private constructor is needed.
class _ThrowingGetFriendListApi implements GetFriendListApi {
  /// The error every [getFriendList] call throws.
  final Object errorToThrow;

  /// How many times [getFriendList] was invoked.
  int callCount = 0;

  _ThrowingGetFriendListApi(this.errorToThrow);

  @override
  Future<FriendListResponse> getFriendList() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [GetFriendListApi] that returns a preset [FriendListResponse] —
/// exercises [GetFriendListRx]'s success path without real HTTP.
class _SucceedingGetFriendListApi implements GetFriendListApi {
  /// The response every [getFriendList] call resolves with.
  final FriendListResponse response;

  /// How many times [getFriendList] was invoked.
  int callCount = 0;

  _SucceedingGetFriendListApi(this.response);

  @override
  Future<FriendListResponse> getFriendList() async {
    callCount++;
    return response;
  }
}

void main() {
  group('GetFriendListRx', () {
    test(
      'getFriendList() delegates to the injected api and reports failure on a thrown error',
      () async {
        // A plain Exception (not a DioException) keeps handleErrorWithReturn
        // off its toast branch, which is not test-safe.
        final error = Exception('network down');
        final fake = _ThrowingGetFriendListApi(error);
        final fetcher = BehaviorSubject<FriendListResponse>();
        final rx = GetFriendListRx(
          api: fake,
          empty: FriendListResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.getFriendList();

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'getFriendList() emits the response and returns true on success',
      () async {
        final response = FriendListResponse(
          success: true,
          message: 'ok',
          code: 200,
          data: [Datum(id: 3, name: 'Bob', email: 'bob@example.com')],
        );
        final fetcher = BehaviorSubject<FriendListResponse>();
        final fake = _SucceedingGetFriendListApi(response);
        final rx = GetFriendListRx(
          api: fake,
          empty: FriendListResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.getFriendList();

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fake.callCount, 1);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetFriendListRx(
        empty: FriendListResponse(),
        dataFetcher: BehaviorSubject<FriendListResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetFriendListApi.instance));
    });
  });
}
