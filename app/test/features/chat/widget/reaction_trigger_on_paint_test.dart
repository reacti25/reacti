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

import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:reacti_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:reacti_app/helpers/feature_flags.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

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
    Duration duration = const Duration(seconds: 4),
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

  setUp(() {
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
}
