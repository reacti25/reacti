// Unit tests for EditMessageRx — the reactive wrapper around the
// edit-message API. Mirrors the DeleteMessageRx tests: an injected fake api
// exercises the success and failure paths without real HTTP.

import 'package:reacti_app/features/chat/data/rx_edit_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_edit_message/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [EditMessageApi] that records its arguments and always throws.
class _ThrowingEditMessageApi implements EditMessageApi {
  final Object errorToThrow;
  int callCount = 0;
  int? lastMessageId;
  String? lastText;

  _ThrowingEditMessageApi(this.errorToThrow);

  @override
  Future<Map> editMessage({
    required int messageId,
    required String text,
  }) async {
    callCount++;
    lastMessageId = messageId;
    lastText = text;
    throw errorToThrow;
  }
}

/// A fake [EditMessageApi] that records its arguments and returns a response.
class _SucceedingEditMessageApi implements EditMessageApi {
  final Map response;
  int? lastMessageId;
  String? lastText;

  _SucceedingEditMessageApi(this.response);

  @override
  Future<Map> editMessage({
    required int messageId,
    required String text,
  }) async {
    lastMessageId = messageId;
    lastText = text;
    return response;
  }
}

void main() {
  group('EditMessageRx', () {
    test(
      'reports failure and surfaces the error on a thrown api error',
      () async {
        // A plain Exception — never a DioException, whose branch calls ToastUtil.
        final error = Exception('edit failed');
        final fake = _ThrowingEditMessageApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = EditMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.editMessage(messageId: 7, text: 'new');

        expect(fake.callCount, 1);
        expect(fake.lastMessageId, 7);
        expect(fake.lastText, 'new');
        expect(result, isFalse);
      },
    );

    test(
      'forwards id + text, emits the response and reports success',
      () async {
        final response = {'success': true};
        final fake = _SucceedingEditMessageApi(response);
        final fetcher = BehaviorSubject<Map>();
        final rx = EditMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

        final result = await rx.editMessage(messageId: 23, text: 'updated');

        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(fake.lastMessageId, 23);
        expect(fake.lastText, 'updated');
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = EditMessageRx(empty: {}, dataFetcher: BehaviorSubject<Map>());
      expect(rx.api, same(EditMessageApi.instance));
    });
  });
}
