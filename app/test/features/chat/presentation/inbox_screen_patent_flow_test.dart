// Full-screen integration harness for the patent flow on InboxScreen.
//
// The existing patent_flow_interactive_test pumps only ReceiverMessageWidget.
// This test pumps the whole InboxScreen — the screen that actually hosts the
// patent flow in production — seeds a sealed (blurred) media message from the
// peer through the real getInboxMessageRx stream + StreamBuilder list, then
// taps the blur placeholder and asserts the full loop fires through the live
// screen: mark-viewed -> silent record -> upload as a `reaction` chained to the
// original message, and the message unblurs in the list.
//
// Everything external is faked so no network/camera/Pusher is needed:
//   - getInboxMessageRx  -> emits a canned InboxResponse (one sealed image)
//   - viewInboxImageRx   -> records the mark-viewed id, returns success
//   - sendMessageRx      -> records the upload arguments
//   - reactionRecorder   -> returns a canned XFile (no real camera)
//   - ChatRealtimeService -> a fake injected via chatRealtimeServiceFactory,
//                            so connect() opens no websocket.
//
// CLAUDE.md mandates an end-to-end regression test for this loop; this is the
// screen-level half (the reconcile-from-Pusher logic is unit-tested in
// test/features/chat/logic/message_reconciler_test.dart).

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_get_inbox_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
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
const int _messageId = 7;
const int _roomId = 99;

/// Fake inbox loader: emits a canned response holding one sealed image message
/// from the peer instead of calling the network.
class _FakeGetInboxMessageRx extends GetInboxMessageRx {
  _FakeGetInboxMessageRx(this._response)
    : super(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

  final InboxResponse _response;

  @override
  Future<bool> getInboxMessage({required int id}) async {
    isBlocked = _response.data?.isBlocked;
    roomId = _response.data?.room?.id;
    handleSuccessWithReturn(_response);
    return true;
  }
}

/// Fake mark-viewed: records the id and returns success immediately.
class _FakeViewInboxImageRx extends ViewInboxImageRx {
  _FakeViewInboxImageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;
  int? lastId;

  @override
  Future<bool> viewInboxImage({required int id}) async {
    callCount++;
    lastId = id;
    return true;
  }
}

/// Fake reaction upload: records every argument the screen passes.
class _FakeSendMessageRx extends SendMessageRx {
  _FakeSendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;
  int? lastId;
  XFile? lastFile;
  String? lastType;
  int? lastReplyToId;

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
    lastId = id;
    lastFile = file;
    lastType = type;
    lastReplyToId = replyToId;
    return true;
  }
}

/// Fake recorder: returns a canned clip without touching the camera plugin.
class _FakeReactionRecorder extends ReactionRecorder {
  int callCount = 0;

  @override
  Future<XFile?> record({
    Duration duration = const Duration(seconds: 4),
  }) async {
    callCount++;
    return XFile('fake/reaction.mp4');
  }
}

/// Canned response: one sealed image message authored by the peer.
InboxResponse _sealedImageResponse() => InboxResponse(
  success: true,
  data: Data(
    isBlocked: false,
    chat: [
      Chat(
        id: _messageId,
        senderId: _peerUserId,
        receiverId: _myUserId,
        roomId: _roomId,
        text: '',
        file: 'https://example.invalid/photo.jpg',
        mediaType: 'image',
        isBlurred: true,
        humanizeDate: 'now',
        sender: Receiver(id: _peerUserId, firstName: 'Alice'),
        receiver: Receiver(id: _myUserId, firstName: 'Me'),
      ),
    ],
  ),
);

/// Wraps [screen] in a ScreenUtil + MaterialApp tree. The navigatorKey is
/// wired because the tap chain's `.waitingForSuccess()` opens a dialog that
/// resolves its context from NavigationService.navigatorKey.
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
  late _FakeGetInboxMessageRx fakeGetInbox;
  late _FakeViewInboxImageRx fakeView;
  late _FakeSendMessageRx fakeSend;
  late _FakeReactionRecorder fakeRecorder;

  late GetInboxMessageRx originalGetInbox;
  late ViewInboxImageRx originalView;
  late SendMessageRx originalSend;
  late ReactionRecorder originalRecorder;
  late ChatRealtimeService Function() originalFactory;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);

    originalGetInbox = api_access.getInboxMessageRx;
    originalView = api_access.viewInboxImageRx;
    originalSend = api_access.sendMessageRx;
    originalRecorder = reactionRecorder;
    originalFactory = chatRealtimeServiceFactory;

    fakeGetInbox = _FakeGetInboxMessageRx(_sealedImageResponse());
    fakeView = _FakeViewInboxImageRx();
    fakeSend = _FakeSendMessageRx();
    fakeRecorder = _FakeReactionRecorder();

    api_access.getInboxMessageRx = fakeGetInbox;
    api_access.viewInboxImageRx = fakeView;
    api_access.sendMessageRx = fakeSend;
    reactionRecorder = fakeRecorder;
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();
  });

  tearDown(() {
    api_access.getInboxMessageRx = originalGetInbox;
    api_access.viewInboxImageRx = originalView;
    api_access.sendMessageRx = originalSend;
    reactionRecorder = originalRecorder;
    chatRealtimeServiceFactory = originalFactory;
  });

  // The loading dialog from .waitingForSuccess() animates forever, so
  // pumpAndSettle() would hang; pump fixed cycles instead.
  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'tapping a sealed message in InboxScreen fires the full patent loop',
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

      // The sealed message renders its tappable placeholder.
      expect(find.text('Click to view the media'), findsOneWidget);

      await tester.tap(find.text('Click to view the media'));
      await drainAsync(tester);

      // Leg 1 — mark-viewed fired with the original message id.
      expect(fakeView.callCount, 1, reason: 'mark-viewed should fire once');
      expect(fakeView.lastId, _messageId);

      // Leg 2 — the silent recording ran after mark-viewed succeeded.
      expect(fakeRecorder.callCount, 1);

      // Leg 3 — the reaction uploaded to the peer, typed and chained.
      expect(fakeSend.callCount, 1, reason: 'reaction sent exactly once');
      expect(fakeSend.lastId, _peerUserId);
      expect(fakeSend.lastType, 'reaction');
      expect(fakeSend.lastReplyToId, _messageId);
      expect(fakeSend.lastFile, isNotNull);

      // The placeholder is gone — the media unblurred in the list.
      expect(find.text('Click to view the media'), findsNothing);
    },
  );

  testWidgets(
    'InboxScreen wires the realtime connection through the injected service',
    (tester) async {
      late FakeChatRealtimeService captured;
      chatRealtimeServiceFactory = () => captured = FakeChatRealtimeService();

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

      // initState calls connect() exactly once on the injected service —
      // proving the screen goes through the swappable factory (no real socket).
      expect(captured.connectCount, 1);
      expect(captured.lastSubscriptions, isNotNull);
      expect(
        captured.lastSubscriptions!.first.channelName,
        'private-chat-room.$_roomId',
      );
    },
  );
}
