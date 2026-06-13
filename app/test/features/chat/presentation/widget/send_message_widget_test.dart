// Widget tests for the composer (SendMessageWidget) after the Option B
// "staged attachment moves inside the composer" fix
// (docs/PLAN-composer-attachment-ux-2026-06-12.md).
//
// They pin: the staged preview renders INSIDE the composer container (not
// floating above the input), the × control clears it, the send button toggles
// its lit/resting state, and — the regression that matters — tapping send with
// a staged attachment still feeds onSend exactly once with the file and media
// type (the optimistic-insert path the rest of the chat/patent pipeline relies
// on). `sendMessageRx` is faked so no network is touched.

import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/presentation/widget/send_message_widget.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// Fake 1:1 sender: records nothing and returns `false` so the success branch
/// (`getAllChatRx.getAllChat()`) is skipped — the composer tests only need the
/// optimistic `onSend` to have fired, and this keeps the widget off the network.
class _StubSendMessageRx extends SendMessageRx {
  _StubSendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    return false;
  }
}

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  late SendMessageRx originalSend;
  late TextEditingController controller;
  late ValueNotifier<XFile?> image;
  late ValueNotifier<String?> mediaType;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    originalSend = api_access.sendMessageRx;
    api_access.sendMessageRx = _StubSendMessageRx();
    controller = TextEditingController();
    image = ValueNotifier<XFile?>(null);
    mediaType = ValueNotifier<String?>(null);
  });

  // Drive layout at a real phone surface so ScreenUtil (designSize 375×812)
  // resolves `.w/.h/.sp` 1:1 instead of over-scaling the default 800×600 test
  // window.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  tearDown(() {
    api_access.sendMessageRx = originalSend;
    controller.dispose();
    image.dispose();
    mediaType.dispose();
  });

  SendMessageWidget composer({Function(String, XFile?, String, int)? onSend}) {
    return SendMessageWidget(
      id: 1,
      isGroup: false,
      messageController: controller,
      image: image,
      mediaType: mediaType,
      onSend: onSend,
    );
  }

  BoxDecoration sendButtonDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.byKey(const Key('composer_send_button')),
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets(
    'staged attachment renders inside the composer container with a remove control and label',
    (tester) async {
      usePhoneSurface(tester);
      image.value = XFile('/tmp/clip.mp4');
      mediaType.value = 'video';

      await tester.pumpWidget(_wrap(composer()));
      await tester.pump();

      final preview = find.byKey(const Key('staged_attachment_preview'));
      final container = find.byKey(const Key('composer_container'));

      expect(preview, findsOneWidget);
      // The preview lives INSIDE the composer container — the same container
      // that holds the send button — rather than floating above the input.
      expect(find.descendant(of: container, matching: preview), findsOneWidget);
      expect(
        find.descendant(
          of: container,
          matching: find.byKey(const Key('composer_send_button')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('remove_staged_attachment')), findsOneWidget);
      expect(find.text('1 video ready to send'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the × clears the staged attachment and hides the preview',
    (tester) async {
      usePhoneSurface(tester);
      image.value = XFile('/tmp/clip.mp4');
      mediaType.value = 'video';

      await tester.pumpWidget(_wrap(composer()));
      await tester.pump();
      expect(
        find.byKey(const Key('staged_attachment_preview')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('remove_staged_attachment')));
      await tester.pump();

      expect(image.value, isNull);
      expect(mediaType.value, isNull);
      expect(find.byKey(const Key('staged_attachment_preview')), findsNothing);
    },
  );

  testWidgets(
    'send button is resting when empty and lit when text or media is staged',
    (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(composer()));
      await tester.pump();

      // Empty composer → resting grey.
      expect(sendButtonDecoration(tester).color, AppColors.c333333);

      // Typed text → lit accent.
      controller.text = 'hello';
      await tester.pump();
      expect(sendButtonDecoration(tester).color, AppColors.allPrimaryColor);

      // No text but a staged attachment → still lit.
      controller.clear();
      image.value = XFile('/tmp/clip.mp4');
      mediaType.value = 'video';
      await tester.pump();
      expect(sendButtonDecoration(tester).color, AppColors.allPrimaryColor);
    },
  );

  testWidgets(
    'tapping send with a staged image invokes onSend once with the file and media type',
    (tester) async {
      usePhoneSurface(tester);
      final calls = <List<dynamic>>[];
      image.value = XFile('/tmp/photo.jpg');
      mediaType.value = 'image';

      await tester.pumpWidget(
        _wrap(
          composer(
            onSend:
                (text, file, media, tempId) =>
                    calls.add([text, file, media, tempId]),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('composer_send_button')));
      await tester.pump();

      expect(calls, hasLength(1));
      final call = calls.single;
      expect((call[1] as XFile?)?.path, '/tmp/photo.jpg'); // file forwarded
      expect(call[2], 'image'); // mediaType forwarded
    },
  );
}
