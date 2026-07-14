// Unit tests for EditGroupMessageRx — the reactive wrapper around the
// group edit-message API. Mirrors the 1:1 EditMessageRx tests.

import 'package:reacti_app/features/chat/data/rx_edit_group_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_edit_group_message/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [EditGroupMessageApi] that records its arguments and always throws.
class _ThrowingEditGroupMessageApi implements EditGroupMessageApi {
  final Object errorToThrow;
  int callCount = 0;
  int? lastGroupId;
  int? lastMessageId;
  String? lastText;

  _ThrowingEditGroupMessageApi(this.errorToThrow);

  @override
  Future<Map> editGroupMessage({
    required int groupId,
    required int messageId,
    required String text,
  }) async {
    callCount++;
    lastGroupId = groupId;
    lastMessageId = messageId;
    lastText = text;
    throw errorToThrow;
  }
}

/// A fake [EditGroupMessageApi] that records its arguments and returns a response.
class _SucceedingEditGroupMessageApi implements EditGroupMessageApi {
  final Map response;
  int? lastGroupId;
  int? lastMessageId;
  String? lastText;

  _SucceedingEditGroupMessageApi(this.response);

  @override
  Future<Map> editGroupMessage({
    required int groupId,
    required int messageId,
    required String text,
  }) async {
    lastGroupId = groupId;
    lastMessageId = messageId;
    lastText = text;
    return response;
  }
}

void main() {
  group('EditGroupMessageRx', () {
    test(
      'reports failure and surfaces the error on a thrown api error',
      () async {
        final error = Exception('edit failed');
        final fake = _ThrowingEditGroupMessageApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = EditGroupMessageRx(
          api: fake,
          empty: {},
          dataFetcher: fetcher,
        );

        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.editGroupMessage(
          groupId: 3,
          messageId: 7,
          text: 'new',
        );

        expect(fake.callCount, 1);
        expect(fake.lastGroupId, 3);
        expect(fake.lastMessageId, 7);
        expect(result, isFalse);
      },
    );

    test('forwards args, emits the response and reports success', () async {
      final response = {'success': true};
      final fake = _SucceedingEditGroupMessageApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = EditGroupMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.editGroupMessage(
        groupId: 9,
        messageId: 23,
        text: 'updated',
      );

      expect(result, isTrue);
      expect(fetcher.value, same(response));
      expect(fake.lastGroupId, 9);
      expect(fake.lastMessageId, 23);
      expect(fake.lastText, 'updated');
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = EditGroupMessageRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );
      expect(rx.api, same(EditGroupMessageApi.instance));
    });
  });
}
