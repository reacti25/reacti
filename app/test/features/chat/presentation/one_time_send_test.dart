// Sending one-time media: the "1" button on the sending screens (the gallery
// review and the composer holding a camera capture) and the two send paths it
// feeds.
//
// The contract: the choice is made on the sending screen, with the media in
// view, never before picking it; it applies to that send only; 1:1 chats and
// groups both offer it while the flag is on; an ordinary send is unchanged.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/presentation/media_picker_mixin.dart';
import 'package:reacti_app/features/chat/presentation/widget/one_time_notice.dart';
import 'package:reacti_app/features/chat/presentation/widget/picked_media_review_screen.dart';
import 'package:reacti_app/features/chat/presentation/widget/send_message_widget.dart';
import 'package:reacti_app/helpers/feature_flags.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

import '../../../support/test_storage.dart';
import '../../../support/widget_harness.dart';

/// Records the one-time flag of every 1:1 send.
class _FakeSendMessageRx extends SendMessageRx {
  _FakeSendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  final List<bool> oneTimeFlags = [];

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
    oneTimeFlags.add(oneTime);
    return true;
  }
}

/// A flag service that answers every flag with [on].
class _FlagSource implements FlagSource {
  _FlagSource(this.on);

  final bool on;

  @override
  bool? cached(String key) => on;

  @override
  Future<void> reload(Iterable<String> keys) async {}
}

/// Minimal host exposing the mixin's batch send and its one-time switch.
class _Host extends StatefulWidget {
  const _Host({required this.group});
  final bool group;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with MediaPickerMixin<_Host> {
  /// The switch as the host saw it while inserting each optimistic bubble.
  final armedAtInsert = <bool>[];

  @override
  int get mediaConversationId => 7;
  @override
  bool get isGroupConversation => widget.group;
  @override
  int insertOptimisticMedia(XFile file, String mediaType, String caption) {
    armedAtInsert.add(oneTimeArmed.value);
    return armedAtInsert.length;
  }

  @override
  void reconcileOptimisticMedia(int tempId, bool success) {}
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _app(Widget home) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (_, _) => MaterialApp(home: Scaffold(body: home)),
);

List<ReviewMediaItem> _photos(int n) => [
  for (var i = 0; i < n; i++)
    ReviewMediaItem(XFile('/tmp/pic_$i.jpg'), 'image'),
];

void main() {
  late SendMessageRx originalSend;
  late _FakeSendMessageRx fakeSend;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    originalSend = api_access.sendMessageRx;
    fakeSend = _FakeSendMessageRx();
    api_access.sendMessageRx = fakeSend;
    FeedbackService.debugPlaySounds = false;
    FeedbackService.setEnabled(false);
  });

  tearDown(() {
    api_access.sendMessageRx = originalSend;
    FeedbackService.debugPlaySounds = true;
    FeedbackService.setEnabled(true);
  });

  const button = Key('one-time-switch');

  group('the "1" button', () {
    testWidgets('a tap turns one-time on, a second tap turns it off', (
      tester,
    ) async {
      final armed = ValueNotifier<bool>(false);
      addTearDown(armed.dispose);
      await pumpInApp(tester, OneTimeToggle(armed: armed));

      await tester.tap(find.byKey(button));
      await tester.pump();
      expect(armed.value, isTrue);

      await tester.tap(find.byKey(button));
      await tester.pump();
      expect(armed.value, isFalse);
    });
  });

  group('who is offered one-time', () {
    Future<_HostState> host(WidgetTester tester, {required bool group}) async {
      await tester.pumpWidget(_app(_Host(group: group)));
      return tester.state<_HostState>(find.byType(_Host));
    }

    tearDown(FeatureFlags.debugResetInstance);

    testWidgets('a 1:1 chat with the flag on', (tester) async {
      FeatureFlags.debugInstance = FeatureFlags.withSource(_FlagSource(true));
      final state = await host(tester, group: false);

      expect(state.oneTimeChoice, same(state.oneTimeArmed));
    });

    testWidgets('nobody while the flag is off (the default)', (tester) async {
      final state = await host(tester, group: false);

      expect(state.oneTimeChoice, isNull);
    });

    testWidgets('a group with the flag on', (tester) async {
      FeatureFlags.debugInstance = FeatureFlags.withSource(_FlagSource(true));
      final state = await host(tester, group: true);

      expect(state.oneTimeChoice, same(state.oneTimeArmed));
    });

    testWidgets('no group while the flag is off', (tester) async {
      final state = await host(tester, group: true);

      expect(state.oneTimeChoice, isNull);
    });

    testWidgets('the attach sheet does not ask: nothing is picked yet', (
      tester,
    ) async {
      FeatureFlags.debugInstance = FeatureFlags.withSource(_FlagSource(true));
      final state = await host(tester, group: false);
      unawaited(state.showMediaPicker(state.context));
      await tester.pumpAndSettle();

      expect(find.text('Gallery'), findsOneWidget, reason: 'the sheet is open');
      expect(find.byKey(button), findsNothing);
    });
  });

  group('gallery review screen', () {
    /// The Android review screen for one picked photo.
    Widget review(ValueNotifier<bool>? armed) => _app(
      PickedMediaReviewScreen(
        files: [XFile('/tmp/pic.jpg')],
        accent: Colors.green,
        onAccent: Colors.white,
        oneTime: armed,
      ),
    );

    testWidgets('the "1" button is in the caption field and says what it '
        'does once on', (tester) async {
      final armed = ValueNotifier<bool>(false);
      addTearDown(armed.dispose);
      await tester.pumpWidget(review(armed));

      expect(find.byKey(const Key('one-time-hint')), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('review-caption')),
          matching: find.byKey(button),
        ),
      );
      await tester.pump();

      expect(armed.value, isTrue);
      expect(find.byKey(const Key('one-time-hint')), findsOneWidget);
    });

    testWidgets('no button when the chat does not offer one-time', (
      tester,
    ) async {
      await tester.pumpWidget(review(null));

      expect(find.byKey(button), findsNothing);
    });
  });

  group('gallery batch', () {
    testWidgets('an armed batch sends every item one-time, then disarms', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Host(group: false)));
      final state = tester.state<_HostState>(find.byType(_Host));
      state.oneTimeArmed.value = true;

      await state.sendMediaBatch(_photos(2), '');

      expect(fakeSend.oneTimeFlags, [true, true]);
      // The host could still read the switch for its optimistic bubbles...
      expect(state.armedAtInsert, [true, true]);
      // ...and it does not carry over to the next message.
      expect(state.oneTimeArmed.value, isFalse);
    });

    testWidgets('an ordinary batch is not one-time', (tester) async {
      await tester.pumpWidget(_app(const _Host(group: false)));
      final state = tester.state<_HostState>(find.byType(_Host));

      await state.sendMediaBatch(_photos(1), '');

      expect(fakeSend.oneTimeFlags, [false]);
    });
  });

  group('composer (camera capture)', () {
    late TextEditingController text;
    late ValueNotifier<XFile?> image;
    late ValueNotifier<String?> mediaType;
    late ValueNotifier<bool> armed;

    setUp(() {
      text = TextEditingController();
      image = ValueNotifier<XFile?>(XFile('/tmp/shot.jpg'));
      mediaType = ValueNotifier<String?>('image');
      armed = ValueNotifier<bool>(false);
    });

    tearDown(() {
      text.dispose();
      image.dispose();
      mediaType.dispose();
      armed.dispose();
    });

    /// The composer, with [onSend] seeing what the host screen would.
    Widget composer({void Function()? onSend}) => _app(
      SendMessageWidget(
        id: 1,
        isGroup: false,
        messageController: text,
        image: image,
        mediaType: mediaType,
        oneTime: armed,
        onSend: (_, _, _, _) => onSend?.call(),
      ),
    );

    testWidgets('a staged photo with the "1" button tapped is sent one-time', (
      tester,
    ) async {
      bool? armedWhenHostInserted;
      await tester.pumpWidget(
        composer(onSend: () => armedWhenHostInserted = armed.value),
      );
      await tester.pump();

      await tester.tap(find.byKey(button));
      await tester.pump();

      // The composer says in words what the lit button means.
      expect(find.byKey(const Key('one-time-staged')), findsOneWidget);

      await tester.tap(find.byKey(const Key('composer_send_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeSend.oneTimeFlags, [true]);
      expect(armedWhenHostInserted, isTrue);
      expect(armed.value, isFalse, reason: 'this message only');
    });

    testWidgets('a staged photo with the switch off is an ordinary send', (
      tester,
    ) async {
      await tester.pumpWidget(composer());
      await tester.pump();

      expect(find.byKey(const Key('one-time-staged')), findsNothing);

      await tester.tap(find.byKey(const Key('composer_send_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeSend.oneTimeFlags, [false]);
    });

    testWidgets('removing the staged photo drops the choice with it', (
      tester,
    ) async {
      armed.value = true;
      await tester.pumpWidget(composer());
      await tester.pump();

      await tester.tap(find.byKey(const Key('remove_staged_attachment')));
      await tester.pump();

      expect(armed.value, isFalse);
      expect(find.byKey(button), findsNothing, reason: 'nothing is staged');
    });

    testWidgets('text alone is never one-time, and the switch is cleared', (
      tester,
    ) async {
      image.value = null;
      mediaType.value = null;
      armed.value = true;
      text.text = 'hello';
      await tester.pumpWidget(composer());
      await tester.pump();

      await tester.tap(find.byKey(const Key('composer_send_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeSend.oneTimeFlags, [false]);
      expect(armed.value, isFalse);
    });
  });
}
