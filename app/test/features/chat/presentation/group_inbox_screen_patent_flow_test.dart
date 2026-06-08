// Full-screen integration harness for the patent flow on GroupInboxScreen.
//
// The group counterpart to inbox_screen_patent_flow_test. Beyond the shared
// loop (mark-viewed -> silent record -> upload as a `reaction`), the group
// screen also performs the OPTIMISTIC INSERT: ReceiverMessageWidget's group
// path fires onReactionSend, which inserts a local "Just now" reaction message
// authored by the current user (rendered by SenderMessageWidget). This test
// pins both: the upload arguments AND that the optimistic message appears.
//
// Everything external is faked (no network/camera/Pusher):
//   - getGroupInboxRx     -> emits a canned GroupInboxResponse (one sealed media)
//   - viewGroupFileRx     -> records the mark-viewed id, returns success
//   - sendGroupMessageRx  -> records the upload arguments
//   - reactionRecorder    -> returns a canned XFile (no real camera)
//   - ChatRealtimeService -> a fake injected via chatRealtimeServiceFactory.

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/reaction_consent.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_get_group_inbox/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_group_file/rx.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../support/fake_chat_realtime_service.dart';
import '../../../support/fake_reaction_consent_gate.dart';
import '../../../support/fake_video_player_platform.dart';
import '../../../support/test_storage.dart';

const int _myUserId = 1;
const int _peerUserId = 42;
const int _messageId = 8;
const int _groupRoomId = 55;

/// Fake group-inbox loader: emits a canned response holding one sealed media
/// message from a peer instead of calling the network.
class _FakeGetGroupInboxRx extends GetGroupInboxRx {
  _FakeGetGroupInboxRx(this._response)
    : super(
        empty: GroupInboxResponse(),
        dataFetcher: BehaviorSubject<GroupInboxResponse>(),
      );

  final GroupInboxResponse _response;

  @override
  Future<bool> getGroupInboxMessage({required int id}) async {
    handleSuccessWithReturn(_response);
    return true;
  }
}

/// Fake group mark-viewed: records the id and returns success.
class _FakeViewGroupFileRx extends ViewGroupFileRx {
  _FakeViewGroupFileRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;
  int? lastId;

  @override
  Future<bool> viewGroupFile({required int id}) async {
    callCount++;
    lastId = id;
    return true;
  }
}

/// Fake group reaction upload: records every argument the screen passes.
class _FakeSendGroupMessageRx extends SendGroupMessageRx {
  _FakeSendGroupMessageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

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
GroupInboxResponse _sealedImageResponse() => GroupInboxResponse(
  success: true,
  data: Data(
    messages: [
      Message(
        id: _messageId,
        groupId: _groupRoomId,
        senderId: _peerUserId,
        text: '',
        file: 'https://example.invalid/photo.jpg',
        mediaType: 'image',
        isBlurred: true,
        createdAt: 'now',
        sender: Sender(id: _peerUserId, firstName: 'Alice'),
      ),
    ],
  ),
);

/// Wraps [screen] in a ScreenUtil + MaterialApp tree, wiring the navigatorKey
/// the tap chain's `.waitingForSuccess()` dialog needs.
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
  late _FakeGetGroupInboxRx fakeGetInbox;
  late _FakeViewGroupFileRx fakeView;
  late _FakeSendGroupMessageRx fakeSend;
  late _FakeReactionRecorder fakeRecorder;

  late GetGroupInboxRx originalGetInbox;
  late ViewGroupFileRx originalView;
  late SendGroupMessageRx originalSend;
  late ReactionRecorder originalRecorder;
  late ChatRealtimeService Function() originalFactory;
  late VideoPlayerPlatform originalVideoPlatform;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);
    // The optimistic reaction renders a video controller; the fake platform
    // makes it initialize without leaving a pending timer.
    originalVideoPlatform = installFakeVideoPlayerPlatform();

    originalGetInbox = api_access.getGroupInboxRx;
    originalView = api_access.viewGroupFileRx;
    originalSend = api_access.sendGroupMessageRx;
    originalRecorder = reactionRecorder;
    originalFactory = chatRealtimeServiceFactory;

    fakeGetInbox = _FakeGetGroupInboxRx(_sealedImageResponse());
    fakeView = _FakeViewGroupFileRx();
    fakeSend = _FakeSendGroupMessageRx();
    fakeRecorder = _FakeReactionRecorder();

    api_access.getGroupInboxRx = fakeGetInbox;
    api_access.viewGroupFileRx = fakeView;
    api_access.sendGroupMessageRx = fakeSend;
    reactionRecorder = fakeRecorder;
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();
    reactionConsentGate = AllowingReactionConsentGate();
  });

  tearDown(() async {
    api_access.getGroupInboxRx = originalGetInbox;
    api_access.viewGroupFileRx = originalView;
    api_access.sendGroupMessageRx = originalSend;
    reactionRecorder = originalRecorder;
    chatRealtimeServiceFactory = originalFactory;
    reactionConsentGate = ReactionConsentGate();
    VideoPlayerPlatform.instance = originalVideoPlatform;
  });

  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'tapping a sealed message in GroupInboxScreen fires the loop and inserts the reaction',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GroupInboxScreen(
            roomId: _groupRoomId,
            name: 'Squad',
            groupImage: '',
          ),
        ),
      );
      await drainAsync(tester);

      // Only the peer's sealed message is present; no message of ours yet.
      expect(find.text('Click to view the media'), findsOneWidget);
      expect(find.byType(SenderMessageWidget), findsNothing);

      await tester.tap(find.text('Click to view the media'));
      await drainAsync(tester);

      // Leg 1 — group mark-viewed with the original message id.
      expect(fakeView.callCount, 1);
      expect(fakeView.lastId, _messageId);

      // Leg 2 — the silent recording ran.
      expect(fakeRecorder.callCount, 1);

      // Leg 3 — the reaction uploaded to the group, typed and chained.
      expect(fakeSend.callCount, 1);
      expect(fakeSend.lastId, _groupRoomId);
      expect(fakeSend.lastType, 'reaction');
      expect(fakeSend.lastReplyToId, _messageId);
      expect(fakeSend.lastFile, isNotNull);

      // Optimistic insert — our reaction now renders as a sent message, and
      // the peer's media unblurred.
      expect(find.byType(SenderMessageWidget), findsOneWidget);
      expect(find.text('Click to view the media'), findsNothing);

      // Rendering the reaction video builds a FlickManager whose one-shot 5s
      // controls-auto-hide timer would otherwise still be pending at teardown
      // (the binding asserts no pending timers). Pump past it so it fires.
      // The fake video platform keeps controller init itself timer-free.
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'GroupInboxScreen wires the realtime connection through the injected service',
    (tester) async {
      late FakeChatRealtimeService captured;
      chatRealtimeServiceFactory = () => captured = FakeChatRealtimeService();

      await tester.pumpWidget(
        _wrap(
          const GroupInboxScreen(
            roomId: _groupRoomId,
            name: 'Squad',
            groupImage: '',
          ),
        ),
      );
      await drainAsync(tester);

      expect(captured.connectCount, 1);
      expect(captured.lastSubscriptions, isNotNull);
      expect(
        captured.lastSubscriptions!.first.channelName,
        'private-group-message.$_myUserId',
      );
    },
  );
}
