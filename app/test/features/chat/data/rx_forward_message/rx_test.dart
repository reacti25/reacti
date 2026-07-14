// Unit tests for ForwardMessageRx — the reactive wrapper around the
// forward-message API. Mirrors the edit/delete Rx tests.

import 'package:reacti_app/features/chat/data/rx_forward_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_forward_message/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ForwardMessageApi] that records its arguments and always throws.
class _ThrowingForwardApi implements ForwardMessageApi {
  final Object errorToThrow;
  int callCount = 0;
  List<Map<String, dynamic>>? lastRecipients;

  _ThrowingForwardApi(this.errorToThrow);

  @override
  Future<Map> forwardMessage({
    required int messageId,
    required String sourceType,
    required List<Map<String, dynamic>> recipients,
  }) async {
    callCount++;
    lastRecipients = recipients;
    throw errorToThrow;
  }
}

/// A fake [ForwardMessageApi] that records its arguments and returns a response.
class _SucceedingForwardApi implements ForwardMessageApi {
  final Map response;
  int? lastMessageId;
  String? lastSourceType;
  List<Map<String, dynamic>>? lastRecipients;

  _SucceedingForwardApi(this.response);

  @override
  Future<Map> forwardMessage({
    required int messageId,
    required String sourceType,
    required List<Map<String, dynamic>> recipients,
  }) async {
    lastMessageId = messageId;
    lastSourceType = sourceType;
    lastRecipients = recipients;
    return response;
  }
}

void main() {
  group('ForwardMessageRx', () {
    test(
      'reports failure and surfaces the error on a thrown api error',
      () async {
        final error = Exception('forward failed');
        final fake = _ThrowingForwardApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = ForwardMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.forwardMessage(
          messageId: 1,
          sourceType: 'single',
          recipients: [
            {'type': 'single', 'id': 2},
          ],
        );

        expect(fake.callCount, 1);
        expect(result, isFalse);
      },
    );

    test('forwards args, emits the response and reports success', () async {
      final response = {
        'success': true,
        'data': {'forwarded_count': 2},
      };
      final fake = _SucceedingForwardApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = ForwardMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final recipients = [
        {'type': 'single', 'id': 11},
        {'type': 'group', 'id': 22},
      ];
      final result = await rx.forwardMessage(
        messageId: 5,
        sourceType: 'group',
        recipients: recipients,
      );

      expect(result, isTrue);
      expect(fetcher.value, same(response));
      expect(fake.lastMessageId, 5);
      expect(fake.lastSourceType, 'group');
      expect(fake.lastRecipients, recipients);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ForwardMessageRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );
      expect(rx.api, same(ForwardMessageApi.instance));
    });
  });
}
