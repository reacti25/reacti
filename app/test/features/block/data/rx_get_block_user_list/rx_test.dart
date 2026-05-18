// Unit tests for GetBlockUserListRx — the reactive wrapper around the
// blocked-user-list API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins GetBlockUserListRx's actual behaviour on both the
// error path and the success path.

import 'package:achiar_expert_app/features/block/data/rx_get_block_user_list/api.dart';
import 'package:achiar_expert_app/features/block/data/rx_get_block_user_list/rx.dart';
import 'package:achiar_expert_app/features/block/model/block_list_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetBlockUserListApi] that always throws a preset error — lets
/// us exercise [GetBlockUserListRx]'s failure path without real HTTP.
/// Uses `implements` so no access to the api's private constructor is
/// needed.
class _ThrowingGetBlockUserListApi implements GetBlockUserListApi {
  /// The error every [getBlockUserList] call throws.
  final Object errorToThrow;

  /// How many times [getBlockUserList] was invoked.
  int callCount = 0;

  _ThrowingGetBlockUserListApi(this.errorToThrow);

  @override
  Future<BlockListResponse> getBlockUserList() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [GetBlockUserListApi] that returns a preset [BlockListResponse]
/// — lets us exercise [GetBlockUserListRx]'s success path without real
/// HTTP.
class _SucceedingGetBlockUserListApi implements GetBlockUserListApi {
  /// The response every [getBlockUserList] call resolves with.
  final BlockListResponse response;

  _SucceedingGetBlockUserListApi(this.response);

  @override
  Future<BlockListResponse> getBlockUserList() async => response;
}

void main() {
  group('GetBlockUserListRx', () {
    test(
      'getBlockUserList() delegates to the injected api and reports failure '
      'on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingGetBlockUserListApi(error);
        final fetcher = BehaviorSubject<BlockListResponse>();
        final rx = GetBlockUserListRx(
          api: fake,
          empty: BlockListResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.getBlockUserList();

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'getBlockUserList() emits the response and reports success',
      () async {
        final response = BlockListResponse(
          success: true,
          message: 'OK',
          code: 200,
          data: Data(
            blockedUsers: [
              BlockedUserElement(id: 1, blockUserId: 9),
            ],
          ),
        );
        final fetcher = BehaviorSubject<BlockListResponse>();
        final rx = GetBlockUserListRx(
          api: _SucceedingGetBlockUserListApi(response),
          empty: BlockListResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.getBlockUserList();

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetBlockUserListRx(
        empty: BlockListResponse(),
        dataFetcher: BehaviorSubject<BlockListResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetBlockUserListApi.instance));
    });
  });
}
