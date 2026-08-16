// Reproduction harness for the reported bug: "after I send a message it does
// not appear until I leave the chat and come back."
//
// Pumps the whole InboxScreen with an EMPTY thread, types a message, taps the
// composer send button, and asserts the message becomes visible WITHOUT any
// re-entry / re-fetch. The only thing that can make it appear is the optimistic
// insert in InboxScreen.onSend. If this test fails, the optimistic insert is
// not reaching the rendered list — which is exactly the user-visible symptom.
//
// Everything external is faked (no network / camera / Pusher):
//   - getInboxMessageRx -> emits an empty thread (room known, no messages)
//   - sendMessageRx     -> records the send, returns success
//   - getAllChatRx      -> no-op (called on send success)
//   - ChatRealtimeService -> fake (connect() opens no websocket)

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/rx_get_all_chat/rx.dart';
import 'package:reacti_app/features/chat/data/rx_get_inbox_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/model/chat_list_response.dart'
    as chat_list;
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../support/fake_chat_realtime_service.dart';
import '../../../support/test_storage.dart';

const int _myUserId = 1;
const int _peerUserId = 42;
const int _roomId = 99;

/// Fake inbox loader. Starts with an empty thread; once [serverHasMessage] is
/// set true (simulating the server having persisted a send), later fetches
/// return a thread containing that message — modelling the real backend, which
/// SAVES the message even when it returns an error status for the send call.
class _FakeGetInboxMessageRx extends GetInboxMessageRx {
  _FakeGetInboxMessageRx()
    : super(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

  bool serverHasMessage = false;
  int fetchCount = 0;

  @override
  Future<bool> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    fetchCount++;
    final chats =
        serverHasMessage
            ? <Chat>[
              Chat(
                id: 555, // a real (small) server id
                senderId: _myUserId,
                receiverId: _peerUserId,
                text: 'hello world',
                mediaType: 'text',
                humanizeDate: 'now',
                sender: Receiver(id: _myUserId, firstName: 'Me'),
                receiver: Receiver(id: _peerUserId, firstName: 'Alice'),
              ),
            ]
            : <Chat>[];
    final response = InboxResponse(
      success: true,
      data: Data(isBlocked: false, chat: chats),
    );
    isBlocked = false;
    roomId = _roomId;
    handleSuccessWithReturn(response);
    return true;
  }
}

/// Fake send that mimics the reported production failure: the backend persists
/// the message but returns an error, so the app sees the send as failed.
class _FakeSendMessageRx extends SendMessageRx {
  _FakeSendMessageRx(this._inbox)
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  final _FakeGetInboxMessageRx _inbox;
  int callCount = 0;

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    callCount++;
    // The row IS saved server-side even though we report failure.
    _inbox.serverHasMessage = true;
    return false;
  }
}

/// Fake chat-list refresh: no-op so send-success doesn't hit the network.
class _FakeGetAllChatRx extends GetAllChatRx {
  _FakeGetAllChatRx()
    : super(
        empty: chat_list.ChatListResponse(),
        dataFetcher: BehaviorSubject<chat_list.ChatListResponse>(),
      );

  @override
  Future<bool> getAllChat() async => true;
}

Widget _wrap(Widget screen) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder:
      (context, _) => MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: screen,
      ),
);

void main() {
  late GetInboxMessageRx originalGetInbox;
  late SendMessageRx originalSend;
  late GetAllChatRx originalGetAllChat;
  late ChatRealtimeService Function() originalFactory;

  late _FakeSendMessageRx fakeSend;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);
    // An established user, not a first-timer: the walkthrough's attach tip
    // draws a full-screen overlay over the composer, and this test is about
    // sending, not about the tip.
    await appData.write(kKeyTourAttachSeen, true);

    originalGetInbox = api_access.getInboxMessageRx;
    originalSend = api_access.sendMessageRx;
    originalGetAllChat = api_access.getAllChatRx;
    originalFactory = chatRealtimeServiceFactory;

    final fakeInbox = _FakeGetInboxMessageRx();
    fakeSend = _FakeSendMessageRx(fakeInbox);
    api_access.getInboxMessageRx = fakeInbox;
    api_access.sendMessageRx = fakeSend;
    api_access.getAllChatRx = _FakeGetAllChatRx();
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();
  });

  tearDown(() {
    api_access.getInboxMessageRx = originalGetInbox;
    api_access.sendMessageRx = originalSend;
    api_access.getAllChatRx = originalGetAllChat;
    chatRealtimeServiceFactory = originalFactory;
  });

  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'a sent message stays visible even when the send call reports failure '
    'but the server saved it (no leave-and-return needed)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const InboxScreen(
            id: _peerUserId,
            roomId: _roomId,
            name: 'Alice',
            image: '',
          ),
        ),
      );
      await drainAsync(tester);

      // Type into the composer and tap send.
      await tester.enterText(find.byType(TextField).last, 'hello world');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer_send_button')));
      await drainAsync(tester);

      // The send fired (and the fake reported failure, as production does)...
      expect(fakeSend.callCount, 1, reason: 'send should dispatch once');
      // ...yet the message must remain on screen WITHOUT leaving and
      // re-entering — the screen self-heals by re-syncing from the server,
      // which has the persisted message.
      expect(
        find.text('hello world'),
        findsOneWidget,
        reason:
            'a saved-but-error-reported message must not silently vanish; '
            'the thread should re-sync and show it',
      );
    },
  );
}
