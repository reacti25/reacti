// Analytics for the C1 reaction-funnel emit points that live in the receiver
// bubble: reaction_send_skipped (early-returns after the media opened) and the
// enriched reaction_recorded.failure_reason (granular camera-failure reason).
//
// Mirrors the harness in patent_flow_interactive_test.dart (fake rx globals +
// NavigationService key) and additionally registers a FakeAnalyticsService so
// the emitted events can be asserted. None of these emits may alter the flow.

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:reacti_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

import '../../../support/fake_analytics_service.dart';

/// mark-viewed that always succeeds (so the flow proceeds to recording/send).
class _OkViewRx extends ViewInboxImageRx {
  _OkViewRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  @override
  Future<bool> viewInboxImage({required int id}) async => true;
}

/// Captures whether a reaction send was attempted.
class _SpySendRx extends SendMessageRx {
  _SpySendRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;

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
    return true;
  }
}

/// Recorder that captured a clip successfully.
class _OkRecorder extends ReactionRecorder {
  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async => XFile('fake/reaction.mp4');
}

/// Recorder that failed with a classified reason (e.g. permission denied).
class _FailRecorder extends ReactionRecorder {
  _FailRecorder(this._reason);
  final String _reason;

  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async {
    lastFailureReason = _reason;
    return null;
  }
}

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder:
      (context, _) => MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
);

void main() {
  late FakeAnalyticsService analytics;
  late ViewInboxImageRx originalView;
  late SendMessageRx originalSend;
  late ReactionRecorder originalRecorder;
  late _SpySendRx spySend;

  setUp(() {
    originalView = api_access.viewInboxImageRx;
    originalSend = api_access.sendMessageRx;
    originalRecorder = reactionRecorder;

    spySend = _SpySendRx();
    api_access.viewInboxImageRx = _OkViewRx();
    api_access.sendMessageRx = spySend;
    reactionRecorder = _OkRecorder();

    analytics = FakeAnalyticsService();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    api_access.viewInboxImageRx = originalView;
    api_access.sendMessageRx = originalSend;
    reactionRecorder = originalRecorder;
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a null messageId emits reaction_send_skipped(null_message_id)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ReceiverMessageWidget(
          message: '',
          avatar: '',
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
          messageId: null,
          userId: 42,
          onUnblur: () {},
          onReply: () {},
          onLongPress: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Click to view the media'));
    await drainAsync(tester);

    final props = analytics.propsOf(Events.reactionSendSkipped)!;
    expect(props[Props.reason], 'null_message_id');
    expect(props[Props.scope], 'private');
  });

  testWidgets('a missing userId emits reaction_send_skipped(missing_user_id)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ReceiverMessageWidget(
          message: '',
          avatar: '',
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
          messageId: 7,
          userId:
              null, // media opens, but there's no one to send the reaction to
          isGroup: false,
          onUnblur: () {},
          onReply: () {},
          onLongPress: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Click to view the media'));
    await drainAsync(tester);

    final props = analytics.propsOf(Events.reactionSendSkipped)!;
    expect(props[Props.reason], 'missing_user_id');
    expect(spySend.callCount, 0);
  });

  testWidgets('a classified recorder failure flows into reaction_recorded', (
    tester,
  ) async {
    reactionRecorder = _FailRecorder('permission_denied');

    await tester.pumpWidget(
      _wrap(
        ReceiverMessageWidget(
          message: '',
          avatar: '',
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
          messageId: 7,
          userId: 42,
          onUnblur: () {},
          onReply: () {},
          onLongPress: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Click to view the media'));
    await drainAsync(tester);

    final props = analytics.propsOf(Events.reactionRecorded)!;
    expect(props[Props.result], 'failure');
    expect(props[Props.failureReason], 'permission_denied');
    // No clip captured -> no reaction sent.
    expect(spySend.callCount, 0);
  });
}
