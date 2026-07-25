// Locks the *interactive* trigger of the patent flow on the client.
//
// What the existing receiver_message_widget_test.dart covers: visual
// states (blur placeholder, reaction bubble, blur-sync). What this
// file adds: the actual call sequence fired when the user taps the
// blur placeholder.
//
// Sequence we expect, in order:
//
//   1. viewInboxImageRx.viewInboxImage(id: messageId) is called
//      → server flips is_viewed=true / is_blurred=false
//   2. reactionRecorder.record() is called
//      → silent 4-second front-camera clip
//   3. sendMessageRx.sendMessage(id: senderId, file: clip,
//        type: "reaction", replyToId: messageId) is called
//      → reaction message uploaded, chains back to the original
//
// If a future refactor of the widget breaks any link in that chain
// (forgets to call mark-viewed, skips the recording, forgets to set
// type:"reaction" or replyToId, etc.) this test goes red.
//
// We swap three globals with fakes:
//
//   - viewInboxImageRx  → captures the message id passed in
//   - sendMessageRx     → captures every argument so we can pin them
//   - reactionRecorder  → returns a canned XFile without touching
//                          the real camera platform channel
//
// The MaterialApp uses NavigationService.navigatorKey so the loading
// dialog opened by .waitingForSuccess() has a context to attach to.

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:reacti_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../support/test_storage.dart';

/// Fake viewInboxImageRx — captures the id and returns success
/// immediately. No HTTP, no real ViewInboxImageApi.
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

/// Fake sendMessageRx — captures every argument the widget passes.
/// The patent-flow assertion is that `type` is "reaction" and
/// `replyToId` is the original message id.
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

/// Fake recorder — returns a canned XFile without touching the
/// `camera` plugin's platform channels. The `duration` arg is
/// ignored so the test doesn't wait the real 4 seconds.
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

/// Wraps [child] in a [ScreenUtilInit] + [MaterialApp] tree.
///
/// The [MaterialApp] is given [NavigationService.navigatorKey] on purpose:
/// `.waitingForSuccess()` opens a loading dialog that resolves its context
/// from that key, so it must be wired or the tap chain throws.
Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder:
        (context, _) => MaterialApp(
          // Crucial — waitingForSuccess() reads context from this key.
          navigatorKey: NavigationService.navigatorKey,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
  );
}

void main() {
  late _FakeViewInboxImageRx fakeView;
  late _FakeSendMessageRx fakeSend;
  late _FakeReactionRecorder fakeRecorder;

  // Stash the production singletons so we can restore them after each
  // test — keeps the test file from leaking fake state into anything
  // that runs after it (defensive; flutter_test runs files in isolated
  // processes, but per-test setUp/tearDown is the safe habit).
  late ViewInboxImageRx originalView;
  late SendMessageRx originalSend;
  late ReactionRecorder originalRecorder;

  setUp(() async {
    // Represent a primed user (the demo primes every first-timer) so the F8c
    // just-in-time primer is skipped and the tap → capture path runs direct.
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
  });

  tearDown(() {
    api_access.viewInboxImageRx = originalView;
    api_access.sendMessageRx = originalSend;
    reactionRecorder = originalRecorder;
  });

  /// Pump the async chain forward. The loading dialog uses a
  /// CircularProgressIndicator which is an infinite animation, so
  /// pumpAndSettle() would hang; manual pump cycles instead.
  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'tapping the blur placeholder fires mark-viewed, records, and uploads as a reaction',
    (tester) async {
      const messageId = 7;
      const senderUserId = 42;

      await tester.pumpWidget(
        _wrap(
          ReceiverMessageWidget(
            message: '',
            avatar: '',
            file: 'https://example.invalid/photo.jpg',
            fileType: 'image',
            isBlurred: true,
            messageId: messageId,
            userId: senderUserId,
            isGroup: false,
            onUnblur: () {},
            onReply: () {},
            onLongPress: (_) {},
          ),
        ),
      );
      await tester.pump();

      // The receiver's only entry point into the patent flow.
      await tester.tap(find.text('Click to view the media'));
      await drainAsync(tester);

      // Leg 1 — mark-viewed.
      expect(
        fakeView.callCount,
        1,
        reason: 'mark-viewed should fire exactly once',
      );
      expect(
        fakeView.lastId,
        messageId,
        reason: 'mark-viewed must carry the original message id',
      );

      // Leg 2 — recording.
      expect(
        fakeRecorder.callCount,
        1,
        reason: 'recordVideoSilently must run after mark-viewed succeeds',
      );

      // Leg 3 — reaction upload.
      expect(
        fakeSend.callCount,
        1,
        reason: 'reaction must be sent exactly once',
      );
      expect(
        fakeSend.lastId,
        senderUserId,
        reason: 'reaction is sent TO the original sender (alice)',
      );
      expect(
        fakeSend.lastType,
        'reaction',
        reason: 'message_type must be "reaction", not "normal"',
      );
      expect(
        fakeSend.lastReplyToId,
        messageId,
        reason: 'reaction must chain back via reply_to_id',
      );
      expect(
        fakeSend.lastFile,
        isNotNull,
        reason: 'the recorded video file must be attached to the upload',
      );
    },
  );

  testWidgets(
    'tapping the blur placeholder when the recorder returns null skips the upload',
    (tester) async {
      // Simulates the "no cameras available" or "user denied permission"
      // branch — the recorder returns null and the widget must NOT send
      // a reaction (otherwise we'd upload a stale or empty file).
      reactionRecorder = _NullReturningRecorder();

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

      // mark-viewed still fired (we did unblur the photo)
      expect(fakeView.callCount, 1);
      // but sendMessage did NOT — recorder returned null, no upload.
      expect(fakeSend.callCount, 0);
    },
  );

  testWidgets(
    'tapping the placeholder a second time after unblur does nothing',
    (tester) async {
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

      // After unblur, the placeholder is gone — there's nothing to tap.
      expect(find.text('Click to view the media'), findsNothing);
      expect(fakeView.callCount, 1);
      expect(fakeSend.callCount, 1);
    },
  );

  testWidgets('tapping with a null messageId is a no-op (guarded, no crash)', (
    tester,
  ) async {
    // An optimistic/malformed realtime message can carry a null id. The
    // tap handler must guard it rather than force-unwrap and throw.
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

    // Nothing fired — no mark-viewed, no recording, no upload, no exception.
    expect(fakeView.callCount, 0);
    expect(fakeRecorder.callCount, 0);
    expect(fakeSend.callCount, 0);
  });

  testWidgets(
    'when mark-viewed fails the media stays blurred and nothing is recorded or sent',
    (tester) async {
      // mark-viewed returning false must not unblur, record, or upload — the
      // placeholder stays so the user can retry.
      final failing = _FailingViewInboxImageRx();
      api_access.viewInboxImageRx = failing;

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

      expect(failing.callCount, 1);
      // Still blurred (placeholder present), and the rest of the chain skipped.
      expect(find.text('Click to view the media'), findsOneWidget);
      expect(fakeRecorder.callCount, 0);
      expect(fakeSend.callCount, 0);
    },
  );
}

/// Fake viewInboxImageRx whose mark-viewed call fails (returns false).
class _FailingViewInboxImageRx extends ViewInboxImageRx {
  _FailingViewInboxImageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;

  @override
  Future<bool> viewInboxImage({required int id}) async {
    callCount++;
    return false;
  }
}

/// Used by the "null clip" test to simulate a failed recording.
class _NullReturningRecorder extends ReactionRecorder {
  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async {
    return null;
  }
}
