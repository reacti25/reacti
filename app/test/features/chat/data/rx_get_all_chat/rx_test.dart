// Unit tests for GetAllChatRx — the reactive wrapper around the
// chat-list API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins GetAllChatRx's actual behaviour on both the
// error path and the success path.

import 'package:achiar_expert_app/features/chat/data/rx_get_all_chat/api.dart';
import 'package:achiar_expert_app/features/chat/data/rx_get_all_chat/rx.dart';
import 'package:achiar_expert_app/features/chat/model/chat_list_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetAllChatApi] that always throws a preset error — lets us
/// exercise [GetAllChatRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the api's private constructor is needed.
class _ThrowingGetAllChatApi implements GetAllChatApi {
  /// The error every [getAllChat] call throws.
  final Object errorToThrow;

  /// How many times [getAllChat] was invoked.
  int callCount = 0;

  _ThrowingGetAllChatApi(this.errorToThrow);

  @override
  Future<ChatListResponse> getAllChat() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [GetAllChatApi] that returns a preset [ChatListResponse] —
/// lets us exercise [GetAllChatRx]'s success path without real HTTP.
class _SucceedingGetAllChatApi implements GetAllChatApi {
  /// The response every [getAllChat] call resolves with.
  final ChatListResponse response;

  /// How many times [getAllChat] was invoked.
  int callCount = 0;

  _SucceedingGetAllChatApi(this.response);

  @override
  Future<ChatListResponse> getAllChat() async {
    callCount++;
    return response;
  }
}

void main() {
  group('GetAllChatRx', () {
    test('getAllChat() delegates to the injected api and reports failure on a '
        'thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('network down');
      final fake = _ThrowingGetAllChatApi(error);
      final fetcher = BehaviorSubject<ChatListResponse>();
      final rx = GetAllChatRx(
        api: fake,
        empty: ChatListResponse(),
        dataFetcher: fetcher,
      );

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.getAllChat();

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('getAllChat() emits the response and reports success', () async {
      final response = ChatListResponse(
        success: true,
        message: 'ok',
        data: Data(chats: [Chat(id: 1, name: 'Alice')]),
      );
      final fetcher = BehaviorSubject<ChatListResponse>();
      final rx = GetAllChatRx(
        api: _SucceedingGetAllChatApi(response),
        empty: ChatListResponse(),
        dataFetcher: fetcher,
      );

      final result = await rx.getAllChat();

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetAllChatRx(
        empty: ChatListResponse(),
        dataFetcher: BehaviorSubject<ChatListResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetAllChatApi.instance));
    });
  });
}
