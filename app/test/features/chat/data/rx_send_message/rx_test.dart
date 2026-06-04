// Unit tests for SendMessageRx — the reactive wrapper around the
// one-to-one message-send API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP.
//
// PATENT FLOW: SendMessageRx uploads `type: "reaction"` clips for the
// silent front-camera recording feature. These tests verify, with extra
// care, that the rx forwards every argument (id, message, type, file,
// replyToId) to the api unchanged and reports the result faithfully.

import 'package:reacti_app/features/chat/data/rx_send_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [SendMessageApi] that records the arguments it was called with
/// and always throws a preset error — exercises [SendMessageRx]'s
/// failure path without real HTTP. Uses `implements` so no access to the
/// api's private constructor is needed.
class _ThrowingSendMessageApi implements SendMessageApi {
  /// The error every [sendMessage] call throws.
  final Object errorToThrow;

  /// How many times [sendMessage] was invoked.
  int callCount = 0;

  _ThrowingSendMessageApi(this.errorToThrow);

  @override
  Future<Map> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [SendMessageApi] that records the arguments it was called with
/// and returns a preset response — exercises [SendMessageRx]'s success
/// path (including the patent `reaction` upload) without real HTTP.
class _SucceedingSendMessageApi implements SendMessageApi {
  /// The response every [sendMessage] call resolves with.
  final Map response;

  /// The `id` passed to the most recent [sendMessage] call.
  int? lastId;

  /// The `message` passed to the most recent [sendMessage] call.
  String? lastMessage;

  /// The `type` passed to the most recent [sendMessage] call.
  String? lastType;

  /// The `replyToId` passed to the most recent [sendMessage] call.
  int? lastReplyToId;

  _SucceedingSendMessageApi(this.response);

  @override
  Future<Map> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    lastId = id;
    lastMessage = message;
    lastType = type;
    lastReplyToId = replyToId;
    return response;
  }
}

void main() {
  group('SendMessageRx', () {
    test('sendMessage() delegates to the injected api and reports failure on a '
        'thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('upload failed');
      final fake = _ThrowingSendMessageApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = SendMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.sendMessage(id: 5, message: 'hi');

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('sendMessage() forwards a reaction message and emits the response on '
        'success', () async {
      // Models the patent-flow upload: a `type: "reaction"` clip.
      final response = {'success': true, 'id': 100};
      final fake = _SucceedingSendMessageApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = SendMessageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.sendMessage(
        id: 9,
        message: 'reaction clip',
        type: 'reaction',
        replyToId: 4,
      );

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
      // Every argument is forwarded to the api unchanged — critical for
      // the patent reaction upload.
      expect(fake.lastId, 9);
      expect(fake.lastMessage, 'reaction clip');
      expect(fake.lastType, 'reaction');
      expect(fake.lastReplyToId, 4);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = SendMessageRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(SendMessageApi.instance));
    });
  });
}
