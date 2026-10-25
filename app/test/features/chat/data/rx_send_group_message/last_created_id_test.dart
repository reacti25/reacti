// Group counterpart of rx_send_message/last_created_id_test. The group screen
// adopts the created id into its optimistic reaction before the react-to-unlock
// re-sync; without it the reaction showed twice (temp id + server copy) until
// the send echo reconciled the temp entry. Pins the `data.message.id` read.

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/rx.dart';
import 'package:rxdart/subjects.dart';

/// Returns a canned response envelope without touching the network.
class _FakeSendGroupMessageApi implements SendGroupMessageApi {
  _FakeSendGroupMessageApi(this._response);

  final Map _response;

  @override
  Future<Map> sendGroupMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async => _response;
}

void main() {
  SendGroupMessageRx makeRx(Map response) => SendGroupMessageRx(
    api: _FakeSendGroupMessageApi(response),
    empty: {},
    dataFetcher: BehaviorSubject<Map>(),
  );

  test(
    'lastCreatedId adopts the server message id from the send response',
    () async {
      final rx = makeRx({
        'data': {
          'message': {'id': 777},
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
        'message': {'id': '888'},
      },
    });

    await rx.sendMessage(id: 42, type: 'reaction');

    expect(rx.lastCreatedId, 888);
  });

  test(
    'lastCreatedId is null when the response omits the message id',
    () async {
      final rx = makeRx({'data': <String, dynamic>{}});

      await rx.sendMessage(id: 42, type: 'reaction');

      expect(rx.lastCreatedId, isNull);
    },
  );
}
