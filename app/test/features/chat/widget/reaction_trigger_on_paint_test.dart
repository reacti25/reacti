// Locks the Phase-1 paint-anchored recording trigger
// (flag `reaction_trigger_on_paint`, branch 1.1 of
// docs/PLAN-media-timing-and-speed-2026-06-23.md).
//
// The flag-OFF behaviour (record immediately after mark-viewed) is pinned by
// patent_flow_interactive_test.dart. This file pins the flag-ON behaviour:
//
//   - the recording does NOT fire immediately on unblur (it is deferred to the
//     first painted frame), and
//   - it still fires EXACTLY ONCE and uploads as a `type:"reaction"` reply —
//     guaranteed by the fallback timeout even if the first frame never paints
//     (the once-guard means a later paint can't double-record).
//
// The painted-vs-timeout split and the overlap_pct win are verified on the
// staging dashboard (the plan's acceptance), not here — a widget test can't
// drive the real decode/paint pipeline deterministically.
//
// What a widget test can pin is WHICH image the trigger waits for: the one the
// bubble shows (decoded at screen width), not the full-size image, which is a
// separate cache entry. The last test puts a ready image under the bubble's
// own cache key and expects the recording to start on its first painted frame.

import 'package:reacti_app/common_widget/inbox_custom_network_image.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:reacti_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/feature_flags.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../support/test_storage.dart';

/// Fake mark-viewed — succeeds immediately, no HTTP.
class _FakeViewInboxImageRx extends ViewInboxImageRx {
  _FakeViewInboxImageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  @override
  Future<bool> viewInboxImage({required int id}) async => true;
}

/// Fake send — counts reaction uploads and captures the type.
class _FakeSendMessageRx extends SendMessageRx {
  _FakeSendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;
  String? lastType;

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
    lastType = type;
    return true;
  }
}

/// Fake recorder — counts captures, returns a canned clip without the camera.
class _FakeReactionRecorder extends ReactionRecorder {
  int callCount = 0;

  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async {
    callCount++;
    return XFile('fake/reaction.mp4');
  }
}

/// [FlagSource] that reports every flag as enabled, so the resolver returns
/// true without a build-time override or a live PostHog.
class _AllOnFlagSource implements FlagSource {
  @override
  bool? cached(String key) => true;

  @override
  Future<void> reload(Iterable<String> keys) async {}
}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder:
        (context, _) => MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
  );
}

void main() {
  late _FakeViewInboxImageRx fakeView;
  late _FakeSendMessageRx fakeSend;
  late _FakeReactionRecorder fakeRecorder;
  late ViewInboxImageRx originalView;
  late SendMessageRx originalSend;
  late ReactionRecorder originalRecorder;

  setUp(() async {
    // Primed user (the demo primes every first-timer) so the F8c primer is
    // skipped and the tap → capture path runs direct.
    await initTestGetStorage();
    await appData.write(kKeyCamMicPrimerShown, true);

    originalView = api_access.viewInboxImageRx;
    originalSend = api_access.sendMessageRx;
    originalRecorder = reactionRecorder;

    fakeView = _FakeViewInboxImageRx();
    fakeSend = _FakeSendMessageRx();
    fakeRecorder = _FakeReactionRecorder();

    api_access.viewInboxImageRx = fakeView;
    api_access.sendMessageRx = fakeSend;
    reactionRecorder = fakeRecorder;

    // Turn the paint-anchored trigger on for these tests.
    FeatureFlags.debugInstance = FeatureFlags.withSource(_AllOnFlagSource());
  });

  tearDown(() {
    api_access.viewInboxImageRx = originalView;
    api_access.sendMessageRx = originalSend;
    reactionRecorder = originalRecorder;
    FeatureFlags.debugResetInstance();
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  /// Pump short cycles to drain the mark-viewed → unblur → arm chain without
  /// settling (the loading dialog's spinner animates forever).
  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget buildBubble() => ReceiverMessageWidget(
    message: '',
    avatar: '',
    file: 'https://example.invalid/photo.jpg',
    fileType: 'image',
    isBlurred: true,
    messageId: 7,
    userId: 42,
    isGroup: false,
    onUnblur: () {},
    onReply: () {},
    onLongPress: (_) {},
  );

  testWidgets(
    'flag on: recording is deferred on unblur, not fired immediately',
    (tester) async {
      await tester.pumpWidget(_wrap(buildBubble()));
      await tester.pump();

      await tester.tap(find.text('Click to view the media'));
      await drainAsync(tester); // mark-viewed resolves, unblur + arm only

      // With the trigger armed (not the immediate path), the recorder has not
      // run yet — it waits for the painted frame / timeout.
      expect(
        fakeRecorder.callCount,
        0,
        reason: 'flag on must defer the recording past unblur',
      );
    },
  );

  testWidgets(
    'flag on: the fallback timeout records exactly once and uploads a reaction',
    (tester) async {
      await tester.pumpWidget(_wrap(buildBubble()));
      await tester.pump();

      await tester.tap(find.text('Click to view the media'));
      await drainAsync(tester);

      // Advance past the 2.5s fallback so the timeout trigger fires.
      await tester.pump(const Duration(milliseconds: 2600));
      await drainAsync(tester); // drain the capture + upload futures

      expect(
        fakeRecorder.callCount,
        1,
        reason: 'fallback timeout must fire the capture exactly once',
      );
      expect(fakeSend.callCount, 1, reason: 'reaction uploaded exactly once');
      expect(fakeSend.lastType, 'reaction');

      // Pump well past again — the once-guard must prevent any second capture.
      await tester.pump(const Duration(seconds: 3));
      await drainAsync(tester);
      expect(
        fakeRecorder.callCount,
        1,
        reason: 'once-guard: no second recording after the first fired',
      );
    },
  );

  testWidgets(
    'flag on: the image the bubble shows, once ready, starts the recording on '
    'its first painted frame',
    (tester) async {
      await tester.pumpWidget(_wrap(buildBubble()));
      await tester.pump();

      // A ready image under the cache key the BUBBLE reads (screen-width
      // decode), as the warm-up leaves it. The full-size key stays empty.
      final provider = InboxCustomNetworkImage.providerFor(
        'https://example.invalid/photo.jpg',
        InboxCustomNetworkImage.decodeWidthOf(
          tester.element(find.byType(ReceiverMessageWidget)),
        ),
      );
      final pixels =
          (await tester.runAsync(() => createTestImage(width: 4, height: 4)))!;
      final key = await provider.obtainKey(ImageConfiguration.empty);
      imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: pixels)),
        ),
      );

      await tester.tap(find.text('Click to view the media'));
      await drainAsync(tester); // 500 ms: far short of the 2.5 s fallback

      expect(
        fakeRecorder.callCount,
        1,
        reason:
            'the recording must start when the image on screen is ready, '
            'not wait for the fallback timeout',
      );
      expect(fakeSend.callCount, 1, reason: 'reaction uploaded exactly once');
      expect(fakeSend.lastType, 'reaction');

      // The bubble drew that same image: one decode serves both.
      final drawn = tester.widget<RawImage>(find.byType(RawImage).first);
      expect(drawn.image?.isCloneOf(pixels), isTrue);

      // Past the fallback: the once-guard still holds.
      await tester.pump(const Duration(seconds: 3));
      await drainAsync(tester);
      expect(fakeRecorder.callCount, 1);
    },
  );
}
