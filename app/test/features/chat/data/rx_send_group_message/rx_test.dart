// Unit tests for SendGroupMessageRx — the reactive wrapper around the
// group message-send API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP.
//
// PATENT FLOW: SendGroupMessageRx uploads `type: "reaction"` clips for
// the silent front-camera recording feature in group chats. These tests
// verify, with extra care, that the rx's `sendMessage` method forwards
// every argument to the api's `sendGroupMessage` unchanged and reports
// the result faithfully.

import 'package:reacti_app/features/chat/data/rx_send_group_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/rx.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [SendGroupMessageApi] that records the arguments it was called
/// with and always throws a preset error — exercises
/// [SendGroupMessageRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the api's private constructor is needed.
class _ThrowingSendGroupMessageApi implements SendGroupMessageApi {
  /// The error every [sendGroupMessage] call throws.
  final Object errorToThrow;

  /// How many times [sendGroupMessage] was invoked.
  int callCount = 0;

  _ThrowingSendGroupMessageApi(this.errorToThrow);

  @override
  Future<Map> sendGroupMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
    bool oneTime = false,
  }) async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [SendGroupMessageApi] that records the arguments it was called
/// with and returns a preset response — exercises [SendGroupMessageRx]'s
/// success path (including the patent `reaction` upload) without real
/// HTTP.
class _SucceedingSendGroupMessageApi implements SendGroupMessageApi {
  /// The response every [sendGroupMessage] call resolves with.
  final Map response;

  /// The `id` passed to the most recent [sendGroupMessage] call.
  int? lastId;

  /// The `message` passed to the most recent [sendGroupMessage] call.
  String? lastMessage;

  /// The `type` passed to the most recent [sendGroupMessage] call.
  String? lastType;

  /// The `replyToId` passed to the most recent [sendGroupMessage] call.
  int? lastReplyToId;

  _SucceedingSendGroupMessageApi(this.response);

  @override
  Future<Map> sendGroupMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
    bool oneTime = false,
  }) async {
    lastId = id;
    lastMessage = message;
    lastType = type;
    lastReplyToId = replyToId;
    return response;
  }
}

void main() {
  group('SendGroupMessageRx', () {
    test('sendMessage() delegates to the injected api and reports failure on a '
        'thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('upload failed');
      final fake = _ThrowingSendGroupMessageApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = SendGroupMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.sendMessage(id: 5, message: 'hi');

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('sendMessage() forwards a reaction message to sendGroupMessage and '
        'emits the response on success', () async {
      // Models the patent-flow upload: a `type: "reaction"` clip.
      final response = {'success': true, 'id': 200};
      final fake = _SucceedingSendGroupMessageApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = SendGroupMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.sendMessage(
        id: 8,
        message: 'reaction clip',
        type: 'reaction',
        replyToId: 6,
      );

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
      // Every argument is forwarded to the api unchanged — critical for
      // the patent reaction upload.
      expect(fake.lastId, 8);
      expect(fake.lastMessage, 'reaction clip');
      expect(fake.lastType, 'reaction');
      expect(fake.lastReplyToId, 6);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = SendGroupMessageRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(SendGroupMessageApi.instance));
    });
  });
}
