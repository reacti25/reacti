// Unit tests for GetInboxMessageRx — the reactive wrapper around the
// one-to-one inbox API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Besides the error/success stream behaviour this file also pins
// the rx's caching of `isBlocked` and `roomId` from the response.

import 'package:reacti_app/features/chat/data/rx_get_inbox_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_get_inbox_message/rx.dart';
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetInboxMessageApi] that records the id it was called with
/// and always throws a preset error — exercises [GetInboxMessageRx]'s
/// failure path without real HTTP. Uses `implements` so no access to the
/// api's private constructor is needed.
class _ThrowingGetInboxMessageApi implements GetInboxMessageApi {
  /// The error every [getInboxMessage] call throws.
  final Object errorToThrow;

  /// How many times [getInboxMessage] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [getInboxMessage] call.
  int? lastId;

  _ThrowingGetInboxMessageApi(this.errorToThrow);

  @override
  Future<InboxResponse> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [GetInboxMessageApi] that returns a preset [InboxResponse] —
/// exercises [GetInboxMessageRx]'s success path without real HTTP.
class _SucceedingGetInboxMessageApi implements GetInboxMessageApi {
  /// The response every [getInboxMessage] call resolves with.
  final InboxResponse response;

  /// The `id` passed to the most recent [getInboxMessage] call.
  int? lastId;

  _SucceedingGetInboxMessageApi(this.response);

  @override
  Future<InboxResponse> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    lastId = id;
    return response;
  }
}

void main() {
  group('GetInboxMessageRx', () {
    test('getInboxMessage() delegates to the injected api and reports failure '
        'on a thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('network down');
      final fake = _ThrowingGetInboxMessageApi(error);
      final fetcher = BehaviorSubject<InboxResponse>();
      final rx = GetInboxMessageRx(
        api: fake,
        empty: InboxResponse(),
        dataFetcher: fetcher,
      );

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.getInboxMessage(id: 42);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastId, 42);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('getInboxMessage() emits the response, caches block/room state and '
        'reports success', () async {
      final response = InboxResponse(
        success: true,
        data: Data(
          isBlocked: true,
          room: DataRoom(id: 99),
          chat: [Chat(id: 1, text: 'hi')],
        ),
      );
      final fetcher = BehaviorSubject<InboxResponse>();
      final rx = GetInboxMessageRx(
        api: _SucceedingGetInboxMessageApi(response),
        empty: InboxResponse(),
        dataFetcher: fetcher,
      );

      final result = await rx.getInboxMessage(id: 7);

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
      // The rx caches block status and room id from the response.
      expect(rx.isBlocked, isTrue);
      expect(rx.roomId, 99);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetInboxMessageRx(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetInboxMessageApi.instance));
    });
  });
}
