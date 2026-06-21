// Unit tests for GetGroupInboxRx — the reactive wrapper around the
// group inbox API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins GetGroupInboxRx's actual behaviour on both the
// error path and the success path.

import 'package:reacti_app/features/chat/data/rx_get_group_inbox/api.dart';
import 'package:reacti_app/features/chat/data/rx_get_group_inbox/rx.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetGroupInboxApi] that records the id it was called with and
/// always throws a preset error — exercises [GetGroupInboxRx]'s failure
/// path without real HTTP. Uses `implements` so no access to the api's
/// private constructor is needed.
class _ThrowingGetGroupInboxApi implements GetGroupInboxApi {
  /// The error every [getGroupInboxMessage] call throws.
  final Object errorToThrow;

  /// How many times [getGroupInboxMessage] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [getGroupInboxMessage] call.
  int? lastId;

  _ThrowingGetGroupInboxApi(this.errorToThrow);

  @override
  Future<GroupInboxResponse> getGroupInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [GetGroupInboxApi] that returns a preset [GroupInboxResponse]
/// — exercises [GetGroupInboxRx]'s success path without real HTTP.
class _SucceedingGetGroupInboxApi implements GetGroupInboxApi {
  /// The response every [getGroupInboxMessage] call resolves with.
  final GroupInboxResponse response;

  /// The `id` passed to the most recent [getGroupInboxMessage] call.
  int? lastId;

  /// The `before` / `limit` cursor params from the most recent call.
  int? lastBefore;
  int? lastLimit;

  _SucceedingGetGroupInboxApi(this.response);

  @override
  Future<GroupInboxResponse> getGroupInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    lastId = id;
    lastBefore = before;
    lastLimit = limit;
    return response;
  }
}

void main() {
  group('GetGroupInboxRx', () {
    test('getGroupInboxMessage() delegates to the injected api and reports '
        'failure on a thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('network down');
      final fake = _ThrowingGetGroupInboxApi(error);
      final fetcher = BehaviorSubject<GroupInboxResponse>();
      final rx = GetGroupInboxRx(
        api: fake,
        empty: GroupInboxResponse(),
        dataFetcher: fetcher,
      );

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.getGroupInboxMessage(id: 12);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastId, 12);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test(
      'getGroupInboxMessage() emits the response and reports success',
      () async {
        final response = GroupInboxResponse(
          success: true,
          data: Data(messages: [Message(id: 1, text: 'hi')]),
        );
        final fetcher = BehaviorSubject<GroupInboxResponse>();
        final rx = GetGroupInboxRx(
          api: _SucceedingGetGroupInboxApi(response),
          empty: GroupInboxResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.getGroupInboxMessage(id: 3);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetGroupInboxRx(
        empty: GroupInboxResponse(),
        dataFetcher: BehaviorSubject<GroupInboxResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetGroupInboxApi.instance));
    });

    test(
      'getGroupInboxMessage() forwards the cursor params to the api',
      () async {
        final fake = _SucceedingGetGroupInboxApi(
          GroupInboxResponse(success: true),
        );
        final rx = GetGroupInboxRx(
          api: fake,
          empty: GroupInboxResponse(),
          dataFetcher: BehaviorSubject<GroupInboxResponse>(),
        );

        await rx.getGroupInboxMessage(id: 3, before: 99, limit: 30);

        expect(fake.lastId, 3);
        expect(fake.lastBefore, 99);
        expect(fake.lastLimit, 30);
      },
    );

    test(
      'fetchOlder() returns the page without pushing onto the stream',
      () async {
        final response = GroupInboxResponse(
          success: true,
          data: Data(messages: [Message(id: 5, text: 'older')]),
        );
        final fake = _SucceedingGetGroupInboxApi(response);
        final fetcher = BehaviorSubject<GroupInboxResponse>();
        final rx = GetGroupInboxRx(
          api: fake,
          empty: GroupInboxResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.fetchOlder(id: 3, before: 6, limit: 30);

        // Returned directly to the caller...
        expect(result, same(response));
        expect(fake.lastBefore, 6);
        expect(fake.lastLimit, 30);
        // ...and the stream was NOT touched (so the screen isn't reset).
        expect(fetcher.hasValue, isFalse);
      },
    );

    test('fetchOlder() returns null on failure instead of throwing', () async {
      final rx = GetGroupInboxRx(
        api: _ThrowingGetGroupInboxApi(Exception('older fetch failed')),
        empty: GroupInboxResponse(),
        dataFetcher: BehaviorSubject<GroupInboxResponse>(),
      );

      final result = await rx.fetchOlder(id: 3, before: 6, limit: 30);

      expect(result, isNull);
    });
  });
}
