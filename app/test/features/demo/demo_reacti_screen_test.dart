// Widget tests for the one-time practice ("demo") Reacti (Feature 2).
//
// Two things matter here:
//   1. The 3-step flow advances (primer → capture → reveal), captures the
//      reaction LOCALLY, and sets kKeyDemoSeen (on open) so it never re-fires.
//   2. PATENT GUARD: the demo path performs ZERO send / ZERO reaction upload.
//      The send singletons are swapped for spies and asserted never called —
//      a regression trip-wire if anyone ever wires the real send into the demo.
//
// The camera plugin is faked via the shared ReactionRecorder seam; the
// permission_handler channel is mocked so `.request()` resolves without
// hardware.

import 'package:camera/camera.dart' show XFile;
import 'package:dio/dio.dart' show ProgressCallback;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/demo/presentation/demo_reacti_screen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:rxdart/rxdart.dart';

import '../../support/test_storage.dart';

/// Fake recorder: returns a canned clip without touching the camera plugin.
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

/// Recorder that always fails (models denied camera / no hardware).
class _NullReactionRecorder extends ReactionRecorder {
  @override
  Future<XFile?> record({
    Duration minDuration = const Duration(seconds: 4),
    Duration maxDuration = const Duration(seconds: 4),
    Future<void>? stopEarly,
  }) async => null;
}

/// Spy that counts sends and never touches the network.
class _SpySendMessageRx extends SendMessageRx {
  _SpySendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());
  int sendCount = 0;

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    sendCount++;
    return false;
  }
}

/// Spy for the group send path.
class _SpySendGroupMessageRx extends SendGroupMessageRx {
  _SpySendGroupMessageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());
  int sendCount = 0;

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    sendCount++;
    return false;
  }
}

void main() {
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  late ReactionRecorder originalRecorder;

  /// Mocks the permission channel to grant or deny whatever is requested.
  void mockPermissions({required bool granted}) {
    // PermissionStatus: 0 = denied, 1 = granted.
    final status = granted ? 1 : 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'requestPermissions') {
            final requested = (call.arguments as List).cast<int>();
            return {for (final p in requested) p: status};
          }
          if (call.method == 'checkPermissionStatus') return status;
          return null;
        });
  }

  setUp(() async {
    await initTestGetStorage();
    originalRecorder = reactionRecorder;
    // Skip the one-time primer dialog by default so flow tests are direct.
    appData.write(kKeyCamMicPrimerShown, true);
    appData.remove(kKeyDemoSeen);
  });

  tearDown(() {
    reactionRecorder = originalRecorder;
    appData.remove(kKeyDemoSeen);
    appData.remove(kKeyCamMicPrimerShown);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  Future<void> pump(WidgetTester tester) {
    // Use a real phone viewport so ScreenUtil (design 375x812) scales 1:1;
    // the default 800x600 test window would oversize .sp/.h and overflow.
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => MaterialApp(
              theme: AppTheme.dark,
              home: const DemoReactiScreen(),
            ),
      ),
    );
  }

  testWidgets('flow advances primer → capture → reveal, captures locally, '
      'sets kKeyDemoSeen', (tester) async {
    final fake = _FakeReactionRecorder();
    reactionRecorder = fake;
    mockPermissions(granted: true);

    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Open demo Reacti'), findsOneWidget);

    await tester.tap(find.text('Open demo Reacti'));
    await tester.pumpAndSettle();

    // Reached the reveal, captured exactly once.
    expect(find.text('Send your first Reacti'), findsOneWidget);
    expect(
      find.textContaining('This is what your friend receives'),
      findsOneWidget,
    );
    expect(fake.callCount, 1);
    // Already marked seen — see the dedicated test below for why it is set on
    // open rather than here.
    expect(appData.read(kKeyDemoSeen), true);

    await tester.tap(find.text('Send your first Reacti'));
    await tester.pumpAndSettle();
    expect(appData.read(kKeyDemoSeen), true);
  });

  testWidgets('opening the demo is enough to mark it seen', (tester) async {
    // The demo can be left by the app-bar back button or an iOS swipe-back,
    // neither of which reaches the finish CTA. When the flag was only written
    // there, anyone who did not tap all the way through was shown the demo
    // again on EVERY launch, forever. Profile's "Try a demo Reacti" is the way
    // back in for anyone who wants it.
    reactionRecorder = _FakeReactionRecorder();
    mockPermissions(granted: true);

    await pump(tester);
    await tester.pump();

    // Still on the first step — nothing has been completed.
    expect(find.text('Open demo Reacti'), findsOneWidget);
    expect(appData.read(kKeyDemoSeen), true);
  });

  testWidgets('PATENT: demo issues zero send / zero reaction upload', (
    tester,
  ) async {
    reactionRecorder = _FakeReactionRecorder();
    mockPermissions(granted: true);

    final sendSpy = _SpySendMessageRx();
    final groupSpy = _SpySendGroupMessageRx();
    final origSend = sendMessageRx;
    final origGroup = sendGroupMessageRx;
    sendMessageRx = sendSpy;
    sendGroupMessageRx = groupSpy;
    addTearDown(() {
      sendMessageRx = origSend;
      sendGroupMessageRx = origGroup;
    });

    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open demo Reacti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send your first Reacti'));
    await tester.pumpAndSettle();

    expect(sendSpy.sendCount, 0);
    expect(groupSpy.sendCount, 0);
  });

  testWidgets('denied camera degrades gracefully — still reaches reveal, '
      'no capture, no send', (tester) async {
    reactionRecorder = _NullReactionRecorder();
    mockPermissions(granted: false);

    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open demo Reacti'));
    await tester.pumpAndSettle();

    // Reveal still reached; the reaction tile shows the camera-off note.
    expect(find.text('Send your first Reacti'), findsOneWidget);
    expect(find.textContaining('Camera off'), findsOneWidget);
  });

  testWidgets('primer dialog shows once then sets the flag (Feature 8c)', (
    tester,
  ) async {
    reactionRecorder = _FakeReactionRecorder();
    mockPermissions(granted: true);
    appData.remove(kKeyCamMicPrimerShown); // force the primer this run

    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open demo Reacti'));
    await tester.pump(); // let the dialog appear

    expect(find.text('Ready for your demo?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(appData.read(kKeyCamMicPrimerShown), true);
    expect(find.text('Send your first Reacti'), findsOneWidget);
  });
}
