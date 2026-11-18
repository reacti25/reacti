// Unit tests for DeleteMessageRx — the reactive wrapper around the
// delete-message API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins DeleteMessageRx's actual behaviour on both the
// error path and the success path.

import 'package:reacti_app/features/chat/data/rx_delete_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_delete_message/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [DeleteMessageApi] that records the id it was called with and
/// always throws a preset error — exercises [DeleteMessageRx]'s failure
/// path without real HTTP. Uses `implements` so no access to the api's
/// private constructor is needed.
class _ThrowingDeleteMessageApi implements DeleteMessageApi {
  /// The error every [deleteMessage] call throws.
  final Object errorToThrow;

  /// How many times [deleteMessage] was invoked.
  int callCount = 0;

  /// The `messageId` passed to the most recent [deleteMessage] call.
  int? lastMessageId;

  _ThrowingDeleteMessageApi(this.errorToThrow);

  @override
  Future<Map> deleteMessage({required int messageId}) async {
    callCount++;
    lastMessageId = messageId;
    throw errorToThrow;
  }

  @override
  Future<Map> deleteGroupMessage({
    required int groupId,
    required int messageId,
  }) async {
    callCount++;
    lastMessageId = messageId;
    throw errorToThrow;
  }
}

/// A fake [DeleteMessageApi] that records the id it was called with and
/// returns a preset response — exercises [DeleteMessageRx]'s success
/// path without real HTTP.
class _SucceedingDeleteMessageApi implements DeleteMessageApi {
  /// The response every [deleteMessage] call resolves with.
  final Map response;

  /// The `messageId` passed to the most recent [deleteMessage] call.
  int? lastMessageId;

  /// The `groupId` passed to the most recent [deleteGroupMessage] call.
  int? lastGroupId;

  _SucceedingDeleteMessageApi(this.response);

  @override
  Future<Map> deleteMessage({required int messageId}) async {
    lastMessageId = messageId;
    return response;
  }

  @override
  Future<Map> deleteGroupMessage({
    required int groupId,
    required int messageId,
  }) async {
    lastGroupId = groupId;
    lastMessageId = messageId;
    return response;
  }
}

void main() {
  group('DeleteMessageRx', () {
    test('deleteMessage() delegates to the injected api and reports failure on '
        'a thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('delete failed');
      final fake = _ThrowingDeleteMessageApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = DeleteMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.deleteMessage(messageId: 55);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastMessageId, 55);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('deleteMessage() forwards the id, emits the response and reports '
        'success', () async {
      final response = {'success': true, 'deleted': true};
      final fake = _SucceedingDeleteMessageApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = DeleteMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.deleteMessage(messageId: 23);

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
      // The message id is forwarded to the api unchanged.
      expect(fake.lastMessageId, 23);
    });

    test('deleteGroupMessage() forwards the group and the message, emits the '
        'response and reports success', () async {
      final response = {'success': true};
      final fake = _SucceedingDeleteMessageApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = DeleteMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.deleteGroupMessage(groupId: 7, messageId: 23);

      expect(result, isTrue);
      expect(fetcher.value, same(response));
      expect(fake.lastGroupId, 7);
      expect(fake.lastMessageId, 23);
    });

    test('deleteGroupMessage() reports failure on a thrown error', () async {
      final error = Exception('delete failed');
      final fake = _ThrowingDeleteMessageApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = DeleteMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      expectLater(fetcher.stream, emitsError(error));

      expect(await rx.deleteGroupMessage(groupId: 7, messageId: 55), isFalse);
      expect(fake.callCount, 1);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = DeleteMessageRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(DeleteMessageApi.instance));
    });
  });
}
