// One-time ("view once") media through the real 1:1 chat screen.
//
// The exchange, end to end:
//
//   the sender sends a one-time photo
//     -> the recipient taps the sealed tile: mark-viewed, the silent reaction
//        recording and its upload run EXACTLY as for ordinary media (the
//        patent loop; one-time must never change it)
//     -> the original sender watches the reaction to the end
//     -> the app reports "finished", the server erases both messages and both
//        phones drop both bubbles.
//
// Around the loop: what each side sees instead of the media (the sender's
// tile, the recipient's "Opened" tile as soon as their reaction is recorded),
// that a one-timer can be neither quoted nor forwarded, and screenshots (kept
// out on Android; on an iPhone reported, and the sender's tile says so).
//
// Fakes: the conversation loader, mark-viewed, the send, the recorder, the
// realtime socket, the video platform and the "finished" call. No network, no
// camera.

import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/common_widget/inbox_custom_network_image.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/one_time_finish_api.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_get_inbox_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/full_screen_image_viewer.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
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
const int _mediaId = 7;
const int _reactionId = 8;
const int _roomId = 99;

/// Emits a canned conversation instead of calling the network.
class _FakeGetInboxMessageRx extends GetInboxMessageRx {
  _FakeGetInboxMessageRx(this._chats)
    : super(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

  final List<Chat> _chats;

  @override
  Future<bool> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    isBlocked = false;
    roomId = _roomId;
    handleSuccessWithReturn(
      InboxResponse(
        success: true,
        data: Data(isBlocked: false, chat: List.of(_chats)),
      ),
    );
    return true;
  }
}

/// Mark-viewed that records the id and succeeds.
class _FakeViewInboxImageRx extends ViewInboxImageRx {
  _FakeViewInboxImageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  final List<int> ids = [];

  @override
  Future<bool> viewInboxImage({required int id}) async {
    ids.add(id);
    return true;
  }
}

/// Send that records what the reaction upload was given.
class _FakeSendMessageRx extends SendMessageRx {
  _FakeSendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;
  String? lastType;
  int? lastReplyToId;
  int? lastId;

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
    return true;
  }
}

/// Recorder that returns a canned clip without touching the camera.
class _FakeReactionRecorder extends ReactionRecorder {
  int callCount = 0;

  /// When set, the recording lasts until this completes (a real one takes
  /// seconds); otherwise it is over at once.
  Completer<void>? hold;

  /// The recording's result; null plays a phone that could not record.
  XFile? clip = XFile('fake/reaction.mp4');

  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async {
    callCount++;
    await hold?.future;
    return clip;
  }
}

/// A realtime event carrying only what the screen reads: a name and a body.
class _FakeEvent extends Fake implements ChannelReadEvent {
  _FakeEvent(this.name, Map<String, Object?> body) : data = json.encode(body);

  @override
  final String name;

  @override
  final dynamic data;
}

/// A one-time photo. [mine] picks who sent it; [opened] whether its recipient
/// has already opened it.
Chat _oneTimePhoto({required bool mine, bool opened = false}) => Chat(
  id: _mediaId,
  senderId: mine ? _myUserId : _peerUserId,
  receiverId: mine ? _peerUserId : _myUserId,
  roomId: _roomId,
  text: '',
  file: 'https://example.invalid/one-time/7/sig/media.jpg',
  mediaType: 'image',
  messageType: 'normal',
  oneTime: true,
  isBlurred: !opened,
  isViewed: opened ? 1 : 0,
  humanizeDate: 'now',
  sender: Receiver(id: mine ? _myUserId : _peerUserId, firstName: 'A'),
  receiver: Receiver(id: mine ? _peerUserId : _myUserId, firstName: 'B'),
);

/// The peer's one-time reaction to my one-time photo. Each test passes its
/// own [url]: the video player cache is static and keyed by URL, so a shared
/// one would hand a later test the previous test's player.
Chat _oneTimeReactionFromPeer(String url) => Chat(
  id: _reactionId,
  senderId: _peerUserId,
  receiverId: _myUserId,
  roomId: _roomId,
  text: '',
  file: url,
  mediaType: 'video',
  messageType: 'reaction',
  oneTime: true,
  isBlurred: false,
  humanizeDate: 'now',
  replyTo: ReplyTo(id: _mediaId, senderId: _myUserId),
  sender: Receiver(id: _peerUserId, firstName: 'Alice'),
  receiver: Receiver(id: _myUserId, firstName: 'Me'),
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
  late _FakeViewInboxImageRx fakeView;
  late _FakeSendMessageRx fakeSend;
  late _FakeReactionRecorder fakeRecorder;
  late FakeChatRealtimeService fakeRealtime;
  late FakeAnalyticsService fakeAnalytics;
  late List<int> finishedReactionIds;
  late List<int> reportedScreenshots;

  late GetInboxMessageRx originalGetInbox;
  late ViewInboxImageRx originalView;
  late SendMessageRx originalSend;
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

    fakeAnalytics = FakeAnalyticsService();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(fakeAnalytics);

    originalGetInbox = api_access.getInboxMessageRx;
    originalView = api_access.viewInboxImageRx;
    originalSend = api_access.sendMessageRx;
    originalRecorder = reactionRecorder;
    originalFactory = chatRealtimeServiceFactory;
    originalFinish = finishOneTimeExchange;
    originalReport = reportOneTimeScreenshot;
    originalSecureScreen = secureScreen;

    fakeView = _FakeViewInboxImageRx();
    fakeSend = _FakeSendMessageRx();
    fakeRecorder = _FakeReactionRecorder();
    fakeRealtime = FakeChatRealtimeService();
    finishedReactionIds = [];

    api_access.viewInboxImageRx = fakeView;
    api_access.sendMessageRx = fakeSend;
    reactionRecorder = fakeRecorder;
    chatRealtimeServiceFactory = () => fakeRealtime;
    finishOneTimeExchange = (id) async {
      finishedReactionIds.add(id);
      return true;
    };
    reportedScreenshots = [];
    reportOneTimeScreenshot = (id) async {
      reportedScreenshots.add(id);
      return true;
    };
    secureScreen = SecureScreen(onPhone: false);
  });

  tearDown(() {
    api_access.getInboxMessageRx = originalGetInbox;
    api_access.viewInboxImageRx = originalView;
    api_access.sendMessageRx = originalSend;
    reactionRecorder = originalRecorder;
    chatRealtimeServiceFactory = originalFactory;
    finishOneTimeExchange = originalFinish;
    reportOneTimeScreenshot = originalReport;
    secureScreen = originalSecureScreen;
    VideoPlayerPlatform.instance = originalVideoPlatform;
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  /// Opens the chat screen on a conversation holding [chats].
  Future<void> openChat(WidgetTester tester, List<Chat> chats) async {
    api_access.getInboxMessageRx = _FakeGetInboxMessageRx(chats);
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
    await drain(tester);
  }

  testWidgets('opening one-time media runs the full patent loop, unchanged', (
    tester,
  ) async {
    fakeRecorder.hold = Completer<void>();
    await openChat(tester, [_oneTimePhoto(mine: false)]);

    // Sealed like any media, and marked as a one-timer.
    expect(find.text('Tap to view once'), findsOneWidget);

    await tester.tap(find.text('Tap to view once'));
    await drain(tester);

    // Leg 1: mark-viewed, for this message.
    expect(fakeView.ids, [_mediaId]);
    // Leg 2: the silent recording is running, with the photo on screen: full
    // screen, with the countdown to its closing.
    expect(fakeRecorder.callCount, 1);
    expect(find.byKey(const Key('one-time-opened')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FullScreenImageViewer),
        matching: find.byType(InboxCustomNetworkImage),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('one-time-countdown')), findsOneWidget);
    expect(fakeAnalytics.countOf(Events.oneTimeOpened), 1);

    fakeRecorder.hold!.complete();
    await drain(tester);

    // Leg 3: the reaction went to the sender, typed and chained to the media.
    expect(fakeSend.callCount, 1);
    expect(fakeSend.lastId, _peerUserId);
    expect(fakeSend.lastType, 'reaction');
    expect(fakeSend.lastReplyToId, _mediaId);

    // The one viewing is over: the full-screen view closes and "Opened" takes
    // the media's place right away, without leaving the chat.
    expect(find.byType(FullScreenImageViewer), findsNothing);
    expect(find.byKey(const Key('one-time-opened')), findsOneWidget);
    expect(find.byType(InboxCustomNetworkImage), findsNothing);
    // Nothing ends the exchange here: that is the original sender's move.
    expect(finishedReactionIds, isEmpty);
  });

  testWidgets('closing the full-screen view early leaves the photo in the '
      'chat until the reaction is recorded', (tester) async {
    fakeRecorder.hold = Completer<void>();
    await openChat(tester, [_oneTimePhoto(mine: false)]);
    await tester.tap(find.text('Tap to view once'));
    await drain(tester);

    await tester.tap(find.byIcon(Icons.close));
    await drain(tester);
    expect(find.byType(FullScreenImageViewer), findsNothing);
    expect(find.byType(InboxCustomNetworkImage), findsOneWidget);

    fakeRecorder.hold!.complete();
    await drain(tester);

    expect(find.byKey(const Key('one-time-opened')), findsOneWidget);
  });

  testWidgets('pausing a one-time video keeps it open; its end closes it', (
    tester,
  ) async {
    const url = 'https://example.invalid/one-time/pause/media.mp4';
    await openChat(tester, [
      _oneTimePhoto(mine: false).copyWith(mediaType: 'video', file: url),
    ]);
    await tester.tap(find.text('Tap to view once'));
    await drain(tester);
    expect(fakeSend.callCount, 1, reason: 'the reaction was recorded');

    final controller =
        VideoControllerCache.getFlickManager(
          url,
        ).flickVideoManager!.videoPlayerController!;
    // Paused part way, say by an accidental tap: it stays open.
    await controller.pause();
    controller.value = controller.value.copyWith(
      position: const Duration(milliseconds: 500),
    );
    await drain(tester);
    expect(find.byKey(const Key('one-time-opened')), findsNothing);
    expect(secureScreen.isOn, isTrue, reason: 'still on screen, still kept');

    // Played to its end: closed for good.
    controller.value = controller.value.copyWith(
      position: controller.value.duration,
    );
    await drain(tester);
    expect(find.byKey(const Key('one-time-opened')), findsOneWidget);
    expect(secureScreen.isOn, isFalse);

    // The video package keeps its controls up after a video ends with a
    // year-long timer; cancel it so the test does not end with it pending.
    VideoControllerCache.getFlickManager(
      url,
    ).flickDisplayManager?.handleShowPlayerControls(showWithTimeout: false);
  });

  testWidgets('an ordinary photo opens in the chat, not full screen', (
    tester,
  ) async {
    fakeRecorder.hold = Completer<void>();
    await openChat(tester, [
      _oneTimePhoto(mine: false).copyWith(oneTime: false),
    ]);
    await tester.tap(find.text('Click to view the media'));
    await drain(tester);

    expect(fakeRecorder.callCount, 1);
    expect(find.byType(FullScreenImageViewer), findsNothing);
    expect(find.byType(InboxCustomNetworkImage), findsOneWidget);
    expect(secureScreen.isOn, isFalse, reason: 'screenshots stay allowed');

    fakeRecorder.hold!.complete();
    await drain(tester);
    // And it stays: only one-time media closes.
    expect(find.byType(InboxCustomNetworkImage), findsOneWidget);
  });

  testWidgets('with no reaction recorded the opened media stays in view', (
    tester,
  ) async {
    // A phone that cannot record answers at once; closing then would hide
    // media the viewer had no time to see.
    fakeRecorder.clip = null;
    await openChat(tester, [_oneTimePhoto(mine: false)]);
    await tester.tap(find.text('Tap to view once'));
    await drain(tester);

    expect(fakeSend.callCount, 0);
    expect(find.byType(InboxCustomNetworkImage), findsOneWidget);
    expect(find.byKey(const Key('one-time-opened')), findsNothing);
  });

  group('screenshots', () {
    testWidgets('an open one-time photo is kept out of screenshots until it '
        'closes', (tester) async {
      fakeRecorder.hold = Completer<void>();
      await openChat(tester, [_oneTimePhoto(mine: false)]);
      expect(secureScreen.isOn, isFalse, reason: 'nothing shows while sealed');

      await tester.tap(find.text('Tap to view once'));
      await drain(tester);
      expect(secureScreen.isOn, isTrue);

      // An iPhone cannot block one: it reports it, and the sender is told.
      secureScreen.debugScreenshot();
      await drain(tester);
      expect(reportedScreenshots, [_mediaId]);
      expect(fakeAnalytics.countOf(Events.oneTimeScreenshot), 1);

      fakeRecorder.hold!.complete();
      await drain(tester);
      expect(find.byKey(const Key('one-time-opened')), findsOneWidget);
      expect(secureScreen.isOn, isFalse);

      // Once it has closed, a screenshot shows nothing of it.
      secureScreen.debugScreenshot();
      await drain(tester);
      expect(reportedScreenshots, [_mediaId]);
    });

    testWidgets("the peer's one-time reaction is kept out of screenshots", (
      tester,
    ) async {
      await openChat(tester, [
        _oneTimeReactionFromPeer(
          'https://example.invalid/one-time/screenshot/media.mp4',
        ),
        _oneTimePhoto(mine: true, opened: true),
      ]);
      expect(secureScreen.isOn, isTrue);

      secureScreen.debugScreenshot();
      await drain(tester);
      expect(reportedScreenshots, [_reactionId]);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await drain(tester);
      expect(secureScreen.isOn, isFalse, reason: 'let go when it leaves');
    });

    testWidgets("the sender's tile says when the peer took a screenshot", (
      tester,
    ) async {
      await openChat(tester, [_oneTimePhoto(mine: true)]);

      fakeRealtime.emit(
        _FakeEvent('OneTimeScreenshotEvent', {
          'chatId': _mediaId,
          'roomId': _roomId,
        }),
      );
      await drain(tester);

      expect(find.text('Screenshot attempt'), findsOneWidget);
      expect(find.text('One-time photo'), findsNothing);
    });

    testWidgets('a screenshot reported earlier shows when the chat opens', (
      tester,
    ) async {
      await openChat(tester, [
        _oneTimePhoto(mine: true).copyWith(oneTimeScreenshot: true),
      ]);

      expect(find.text('Screenshot attempt'), findsOneWidget);
    });
  });

  testWidgets('one-time media opened on an earlier visit shows "Opened"', (
    tester,
  ) async {
    await openChat(tester, [_oneTimePhoto(mine: false, opened: true)]);

    expect(find.byKey(const Key('one-time-opened')), findsOneWidget);
    expect(find.text('Opened'), findsOneWidget);
    // The file is never loaded a second time.
    expect(find.byType(InboxCustomNetworkImage), findsNothing);
    expect(find.text('Tap to view once'), findsNothing);
  });

  testWidgets('the sender sees a tile, never their own one-time media', (
    tester,
  ) async {
    await openChat(tester, [_oneTimePhoto(mine: true)]);

    expect(find.byKey(const Key('one-time-sent')), findsOneWidget);
    expect(find.text('One-time photo'), findsOneWidget);
    expect(find.byType(InboxCustomNetworkImage), findsNothing);
  });

  testWidgets('the sender\'s tile turns to "Opened" when the peer opens it', (
    tester,
  ) async {
    await openChat(tester, [_oneTimePhoto(mine: true)]);

    fakeRealtime.emit(
      _FakeEvent('MessageReadEvent', {
        'roomId': _roomId,
        'userId': _peerUserId,
        'messageId': _mediaId,
      }),
    );
    await drain(tester);

    expect(find.text('Opened'), findsOneWidget);
    expect(find.text('One-time photo'), findsNothing);
  });

  testWidgets(
    'watching the one-time reaction to the end finishes the exchange',
    (tester) async {
      await openChat(tester, [
        _oneTimeReactionFromPeer(
          'https://example.invalid/one-time/watch-to-end/media.mp4',
        ),
        _oneTimePhoto(mine: true, opened: true),
      ]);
      expect(find.text('Reaction, plays once'), findsOneWidget);
      expect(find.byKey(const Key('one-time-sent')), findsOneWidget);

      // Press play, then let it run to its end.
      final controller =
          VideoControllerCache.getFlickManager(
            'https://example.invalid/one-time/watch-to-end/media.mp4',
          ).flickVideoManager!.videoPlayerController!;
      controller.value = controller.value.copyWith(isPlaying: true);
      await tester.pump();
      expect(finishedReactionIds, isEmpty, reason: 'not before it has ended');

      controller.value = controller.value.copyWith(
        position: controller.value.duration,
        isPlaying: false,
      );
      await drain(tester);

      // The server is asked, once, to erase the exchange...
      expect(finishedReactionIds, [_reactionId]);
      expect(fakeAnalytics.countOf(Events.oneTimeReactionWatched), 1);
      // ...and both bubbles are gone at once.
      expect(find.text('Reaction, plays once'), findsNothing);
      expect(find.byKey(const Key('one-time-sent')), findsNothing);

      // The video package keeps its controls up after a video ends with a
      // year-long timer; cancel it so the test does not end with it pending.
      VideoControllerCache.getFlickManager(
        'https://example.invalid/one-time/watch-to-end/media.mp4',
      ).flickDisplayManager?.handleShowPlayerControls(showWithTimeout: false);
    },
  );

  testWidgets('leaving mid-watch still finishes the exchange', (tester) async {
    await openChat(tester, [
      _oneTimeReactionFromPeer(
        'https://example.invalid/one-time/leave-mid-watch/media.mp4',
      ),
      _oneTimePhoto(mine: true, opened: true),
    ]);

    final controller =
        VideoControllerCache.getFlickManager(
          'https://example.invalid/one-time/leave-mid-watch/media.mp4',
        ).flickVideoManager!.videoPlayerController!;
    controller.value = controller.value.copyWith(isPlaying: true);
    await tester.pump();

    // Leave the chat without reaching the end.
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await drain(tester);

    expect(finishedReactionIds, [_reactionId]);
  });

  testWidgets('a one-time reaction that was never played is left alone', (
    tester,
  ) async {
    await openChat(tester, [
      _oneTimeReactionFromPeer(
        'https://example.invalid/one-time/never-played/media.mp4',
      ),
      _oneTimePhoto(mine: true, opened: true),
    ]);

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await drain(tester);

    expect(finishedReactionIds, isEmpty);
  });

  testWidgets('the server\'s erase signal removes the bubbles on the peer', (
    tester,
  ) async {
    // The recipient's side: their own one-time reaction and the opened media.
    await openChat(tester, [_oneTimePhoto(mine: false, opened: true)]);
    expect(find.byKey(const Key('one-time-opened')), findsOneWidget);

    fakeRealtime.emit(
      _FakeEvent('MessageDeletedEvent', {
        'chatId': _mediaId,
        'roomId': _roomId,
        'deleteType': 'for_everyone',
      }),
    );
    await drain(tester);

    expect(find.byKey(const Key('one-time-opened')), findsNothing);
  });

  testWidgets('a conversation answer that lands after the erase does not '
      'bring the bubbles back', (tester) async {
    await openChat(tester, [_oneTimePhoto(mine: false, opened: true)]);

    fakeRealtime.emit(
      _FakeEvent('MessageDeletedEvent', {
        'chatId': _mediaId,
        'roomId': _roomId,
        'deleteType': 'for_everyone',
      }),
    );
    await drain(tester);
    expect(find.byKey(const Key('one-time-opened')), findsNothing);

    // A fetch that started before the erase answers now, still holding the
    // erased message (the fake replays the same conversation).
    await api_access.getInboxMessageRx.getInboxMessage(id: _peerUserId);
    await drain(tester);

    expect(find.byKey(const Key('one-time-opened')), findsNothing);
  });

  testWidgets('a one-timer can be neither quoted nor forwarded', (
    tester,
  ) async {
    await openChat(tester, [_oneTimePhoto(mine: true)]);

    await tester.longPress(find.byKey(const Key('one-time-sent')));
    await drain(tester);

    expect(find.text('Delete'), findsOneWidget, reason: 'the menu opened');
    expect(find.text('Reply'), findsNothing);
    expect(find.text('Forward'), findsNothing);
  });
}

/// Pumps the async chain forward. The loading dialog behind mark-viewed
/// animates forever, so pumpAndSettle() would hang; the last long pump clears
/// the video controls' one-shot auto-hide timer.
Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(seconds: 6));
}
