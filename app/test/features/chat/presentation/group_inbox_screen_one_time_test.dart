// One-time media in a group chat, as one member's app sees it:
//
// - a one-time photo from another member opens once, through the unchanged
//   patent loop (mark-viewed -> silent recording -> reaction upload), is kept
//   out of screenshots while open, and is then over for this member only;
// - another member's one-time reaction plays once and then leaves this chat;
// - an erased one-timer shows "N of M reacted", for the sender too;
// - the server's one-time signal, and a one-timer's own broadcast, reload the
//   thread (a broadcast carries no link: every member has their own);
// - a one-timer is never quoted or forwarded.

import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/one_time_finish_api.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_get_group_inbox/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_group_file/rx.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/secure_screen.dart';
import 'package:reacti_app/helpers/video_controller_cache.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../support/fake_analytics_service.dart';
import '../../../support/fake_chat_realtime_service.dart';
import '../../../support/fake_video_player_platform.dart';
import '../../../support/test_storage.dart';

const int _myUserId = 1;
const int _peerUserId = 42;
const int _groupId = 55;
const int _mediaId = 8;
const int _reactionId = 100;

/// Replays [messages] on every fetch and counts the fetches.
class _FakeGetGroupInboxRx extends GetGroupInboxRx {
  _FakeGetGroupInboxRx(this.messages)
    : super(
        empty: GroupInboxResponse(),
        dataFetcher: BehaviorSubject<GroupInboxResponse>(),
      );

  List<Message> messages;
  int callCount = 0;

  @override
  Future<bool> getGroupInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    callCount++;
    handleSuccessWithReturn(
      GroupInboxResponse(
        success: true,
        data: Data(
          messages: List.of(messages),
          pagination: Pagination(hasMore: false),
        ),
      ),
    );
    return true;
  }
}

class _FakeViewGroupFileRx extends ViewGroupFileRx {
  _FakeViewGroupFileRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  final ids = <int>[];

  @override
  Future<bool> viewGroupFile({required int id}) async {
    ids.add(id);
    return true;
  }
}

class _FakeSendGroupMessageRx extends SendGroupMessageRx {
  _FakeSendGroupMessageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;
  int? lastId;
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
    bool oneTime = false,
  }) async {
    callCount++;
    lastId = id;
    lastType = type;
    lastReplyToId = replyToId;
    lastCreatedId = 500;
    return true;
  }
}

/// Records at once, or when [hold] completes.
class _FakeReactionRecorder extends ReactionRecorder {
  int callCount = 0;
  Completer<void>? hold;

  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async {
    callCount++;
    await hold?.future;
    return XFile('fake/reaction.mp4');
  }
}

class _FakeEvent extends Fake implements ChannelReadEvent {
  _FakeEvent(this.name, Map<String, Object?> body) : data = json.encode(body);

  @override
  final String name;

  @override
  final dynamic data;
}

/// A one-time photo in the group. [mine] picks who sent it.
Message _oneTimePhoto({required bool mine}) => Message(
  id: _mediaId,
  groupId: _groupId,
  senderId: mine ? _myUserId : _peerUserId,
  text: '',
  // The sender gets no link to their own one-timer.
  file: mine ? null : 'https://example.invalid/group-one-time-media/8/1/sig',
  mediaType: 'image',
  messageType: 'normal',
  isBlurred: !mine,
  createdAt: 'now',
  sender: Sender(id: mine ? _myUserId : _peerUserId, firstName: 'A'),
  isOneTime: true,
);

/// Another member's one-time reaction to my one-time photo, on its own [url]
/// (the video player cache is static and keyed by URL).
Message _oneTimeReactionFromPeer(String url) => Message(
  id: _reactionId,
  groupId: _groupId,
  senderId: _peerUserId,
  text: '',
  file: url,
  mediaType: 'video',
  messageType: 'reaction',
  isBlurred: false,
  createdAt: 'now',
  sender: Sender(id: _peerUserId, firstName: 'Alice'),
  replyTo: ReplyTo(id: _mediaId, senderId: _myUserId),
  isOneTime: true,
);

/// An erased one-timer: only its trace, 2 of 3 members reacted.
Message _erased({required bool mine}) => Message(
  id: mine ? _mediaId : _mediaId + 1,
  groupId: _groupId,
  senderId: mine ? _myUserId : _peerUserId,
  text: null,
  mediaType: 'image',
  messageType: 'normal',
  isBlurred: false,
  createdAt: 'now',
  sender: Sender(id: mine ? _myUserId : _peerUserId, firstName: 'A'),
  isOneTime: true,
  oneTimeErased: true,
  oneTimeReacted: 2,
  oneTimeRecipients: 3,
);

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
  late FakeChatRealtimeService fakeRealtime;
  late List<int> finished;
  late List<int> reportedScreenshots;

  late GetGroupInboxRx originalGetInbox;
  late ViewGroupFileRx originalView;
  late SendGroupMessageRx originalSend;
  late ReactionRecorder originalRecorder;
  late ChatRealtimeService Function() originalFactory;
  late VideoPlayerPlatform originalVideoPlatform;
  late Future<bool> Function(int) originalFinish;
  late Future<bool> Function(int) originalReport;
  late SecureScreen originalSecureScreen;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);
    await appData.write(kKeyCamMicPrimerShown, true);
    originalVideoPlatform = installFakeVideoPlayerPlatform();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(FakeAnalyticsService());

    originalGetInbox = api_access.getGroupInboxRx;
    originalView = api_access.viewGroupFileRx;
    originalSend = api_access.sendGroupMessageRx;
    originalRecorder = reactionRecorder;
    originalFactory = chatRealtimeServiceFactory;
    originalFinish = finishGroupOneTime;
    originalReport = reportGroupOneTimeScreenshot;
    originalSecureScreen = secureScreen;

    fakeView = _FakeViewGroupFileRx();
    fakeSend = _FakeSendGroupMessageRx();
    fakeRecorder = _FakeReactionRecorder();
    fakeRealtime = FakeChatRealtimeService();
    finished = [];
    reportedScreenshots = [];

    api_access.viewGroupFileRx = fakeView;
    api_access.sendGroupMessageRx = fakeSend;
    reactionRecorder = fakeRecorder;
    chatRealtimeServiceFactory = () => fakeRealtime;
    finishGroupOneTime = (id) async {
      finished.add(id);
      return true;
    };
    reportGroupOneTimeScreenshot = (id) async {
      reportedScreenshots.add(id);
      return true;
    };
    secureScreen = SecureScreen(onPhone: false);
  });

  tearDown(() {
    api_access.getGroupInboxRx = originalGetInbox;
    api_access.viewGroupFileRx = originalView;
    api_access.sendGroupMessageRx = originalSend;
    reactionRecorder = originalRecorder;
    chatRealtimeServiceFactory = originalFactory;
    finishGroupOneTime = originalFinish;
    reportGroupOneTimeScreenshot = originalReport;
    secureScreen = originalSecureScreen;
    VideoPlayerPlatform.instance = originalVideoPlatform;
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  Future<void> openGroup(WidgetTester tester, List<Message> messages) async {
    fakeGetInbox = _FakeGetGroupInboxRx(messages);
    api_access.getGroupInboxRx = fakeGetInbox;
    await tester.pumpWidget(
      _wrap(
        const GroupInboxScreen(roomId: _groupId, name: 'Squad', groupImage: ''),
      ),
    );
    await drain(tester);
  }

  testWidgets('a one-time photo opens once through the patent loop, is kept '
      'out of screenshots while open, then is over for this member', (
    tester,
  ) async {
    fakeRecorder.hold = Completer<void>();
    await openGroup(tester, [_oneTimePhoto(mine: false)]);
    expect(find.text('Tap to view once'), findsOneWidget);

    await tester.tap(find.text('Tap to view once'));
    await drain(tester);

    // Mark-viewed for this message, then the silent recording, while the
    // photo is open and screenshots are blocked.
    expect(fakeView.ids, [_mediaId]);
    expect(fakeRecorder.callCount, 1);
    expect(secureScreen.isOn, isTrue);
    secureScreen.debugScreenshot();
    await tester.pump();
    expect(reportedScreenshots, [_mediaId]);

    fakeRecorder.hold!.complete();
    await drain(tester);

    // The reaction went to the group, typed and chained to the media.
    expect(fakeSend.callCount, 1);
    expect(fakeSend.lastId, _groupId);
    expect(fakeSend.lastType, 'reaction');
    expect(fakeSend.lastReplyToId, _mediaId);
    // Closed for this member, and the server is told they are done.
    expect(find.byKey(const Key('one-time-opened')), findsOneWidget);
    expect(secureScreen.isOn, isFalse);
    expect(finished, [_mediaId]);
  });

  testWidgets("another member's one-time reaction plays once, then leaves "
      'this chat', (tester) async {
    const url = 'https://example.invalid/group-one-time/watch/media.mp4';
    await openGroup(tester, [
      _oneTimeReactionFromPeer(url),
      _oneTimePhoto(mine: true),
    ]);
    expect(find.text('Reaction, plays once'), findsOneWidget);
    expect(find.text('One-time photo'), findsOneWidget, reason: 'my own tile');

    final controller =
        VideoControllerCache.getFlickManager(
          url,
        ).flickVideoManager!.videoPlayerController!;
    controller.value = controller.value.copyWith(isPlaying: true);
    await tester.pump();
    expect(secureScreen.isOn, isTrue);
    expect(finished, isEmpty, reason: 'not before it has ended');

    controller.value = controller.value.copyWith(
      position: controller.value.duration,
      isPlaying: false,
    );
    await drain(tester);

    expect(finished, [_reactionId]);
    expect(find.text('Reaction, plays once'), findsNothing);
    expect(secureScreen.isOn, isFalse);
    // My photo is not erased by one member watching: others may not be done.
    expect(find.text('One-time photo'), findsOneWidget);

    VideoControllerCache.getFlickManager(
      url,
    ).flickDisplayManager?.handleShowPlayerControls(showWithTimeout: false);
  });

  testWidgets('an erased one-timer shows how many members reacted, on both '
      'sides', (tester) async {
    await openGroup(tester, [_erased(mine: false), _erased(mine: true)]);

    expect(find.text('One-time photo · 2 of 3 reacted'), findsNWidgets(2));
    expect(find.text('Tap to view once'), findsNothing);
  });

  testWidgets("the server's one-time signal reloads this group only", (
    tester,
  ) async {
    await openGroup(tester, [_oneTimePhoto(mine: false)]);
    final loads = fakeGetInbox.callCount;

    fakeRealtime.emit(_FakeEvent('GroupOneTimeChangedEvent', {'groupId': 77}));
    await drain(tester);
    expect(fakeGetInbox.callCount, loads);

    fakeGetInbox.messages = [_erased(mine: false)];
    fakeRealtime.emit(
      _FakeEvent('GroupOneTimeChangedEvent', {'groupId': _groupId}),
    );
    await drain(tester);
    expect(fakeGetInbox.callCount, loads + 1);
    expect(find.text('One-time photo · 2 of 3 reacted'), findsOneWidget);
  });

  testWidgets('a one-timer that arrives live reloads the thread instead of '
      'showing the shared broadcast', (tester) async {
    await openGroup(tester, []);
    final loads = fakeGetInbox.callCount;
    fakeGetInbox.messages = [_oneTimePhoto(mine: false)];

    fakeRealtime.emit(
      _FakeEvent('App\\Events\\GroupMessageSendEvent', {
        'message': {
          'id': _mediaId,
          'group_id': _groupId,
          'sender_id': _peerUserId,
          'file': null,
          'is_one_time': true,
          'message_type': 'normal',
        },
      }),
    );
    await drain(tester);

    expect(fakeGetInbox.callCount, loads + 1);
    expect(find.text('Tap to view once'), findsOneWidget);
  });

  testWidgets('a one-timer can be neither quoted nor forwarded', (
    tester,
  ) async {
    await openGroup(tester, [_oneTimePhoto(mine: true)]);

    await tester.longPress(find.byKey(const Key('one-time-sent')));
    await drain(tester);

    expect(find.text('Details'), findsOneWidget, reason: 'the menu opened');
    expect(find.text('Reply'), findsNothing);
    expect(find.text('Forward'), findsNothing);
  });
}

/// Pumps the async chain forward; pumpAndSettle would hang on the loading
/// dialog behind mark-viewed. The long pump clears the video controls' timer.
Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(seconds: 6));
}
