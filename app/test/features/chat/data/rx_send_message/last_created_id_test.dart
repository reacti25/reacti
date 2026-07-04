// Guards the fix for the 1:1 reaction "watched" dot greening only on the
// SECOND watch. Root cause: the 1:1 send is not echoed back to the sender, so
// the optimistic reaction kept its temp id and the live MessageReadEvent (which
// carries the real server id) never matched it until a re-fetch landed — which
// raced the media sender's first watch. The fix threads the real server id out
// of the send response via SendMessageRx.lastCreatedId so the optimistic entry
// can adopt it synchronously. This test pins that extraction.

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:rxdart/subjects.dart';

/// Returns a canned response envelope without touching the network.
class _FakeSendMessageApi implements SendMessageApi {
  _FakeSendMessageApi(this._response);

  final Map _response;

  @override
  Future<Map> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async => _response;
}

void main() {
  SendMessageRx makeRx(Map response) => SendMessageRx(
    api: _FakeSendMessageApi(response),
    empty: {},
    dataFetcher: BehaviorSubject<Map>(),
  );

  test(
    'lastCreatedId adopts the server chat id from the send response',
    () async {
      final rx = makeRx({
        'data': {
          'chat': {'id': 777},
        },
      });

      final ok = await rx.sendMessage(id: 42, type: 'reaction');

      expect(ok, isTrue);
      expect(rx.lastCreatedId, 777);
    },
  );

  test('lastCreatedId parses a string id', () async {
    final rx = makeRx({
      'data': {
        'chat': {'id': '888'},
      },
    });

    await rx.sendMessage(id: 42, type: 'reaction');

    expect(rx.lastCreatedId, 888);
  });

  test('lastCreatedId is null when the response omits the chat id', () async {
    final rx = makeRx({'data': <String, dynamic>{}});

    await rx.sendMessage(id: 42, type: 'reaction');

    expect(rx.lastCreatedId, isNull);
  });
}
