// Render-state tests for the patent-flow widget.
//
// What this file covers:
//   The visual states ReceiverMessageWidget passes through during the
//   patent flow — plain text, blurred media (the "Click to view the media"
//   placeholder), and the "Reaction" bubble. If any of these visual
//   contracts break, this test fails.
//
// What this file does NOT cover (yet):
//   The actual interactive trigger:
//
//     tap blur placeholder
//       -> viewInboxImageRx.viewInboxImage(...).waitingForSuccess()
//          -> setState(_isBlurred = false)
//             -> recordVideoSilently()
//                -> sendMessageRx.sendMessage(type: "reaction", ...)
//
//   Locking that flow in a widget test requires either:
//
//     1. Refactoring ReceiverMessageWidget so the rx_* singletons,
//        recordVideoSilently(), and NavigationService context are
//        injected via constructor (proper DI), or
//     2. An integration_test/ test that boots a fake camera platform
//        channel + a fake HTTP server.
//
//   Both are tracked as Phase-4 follow-ups in docs/testing/inventory.md.
//   Until one lands, the *server-side* ReactionFlowTest.php is what
//   guarantees the loop end-to-end; this file guarantees the *visual
//   contract* the loop depends on.
//
// Convention this file establishes for future widget tests:
//   - Wrap the widget in `ScreenUtilInit` so `.h`/`.w`/`.r`/`.sp`
//     extensions resolve.
//   - Wrap in `MaterialApp(home: Material(...))` so MediaQuery,
//     Directionality, and theme are available.
//   - Avoid props that hit platform plugins (don't pass `fileType:
//     'video'` here — that initializes flick_video_player + the cache
//     and requires real video controllers).

import 'package:reacti_app/features/chat/presentation/widget/receiver_message_widget.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimum tree a [ReceiverMessageWidget] needs to
/// render, optionally under a specific [theme].
///
/// [ScreenUtilInit] makes the `.h`/`.w`/`.r`/`.sp` sizing extensions
/// resolve; the [MaterialApp]/[Scaffold] put [MediaQuery], [Directionality],
/// and the theme in scope.
Widget _wrap(Widget child, {ThemeData? theme}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder:
        (context, _) => MaterialApp(
          theme: theme,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
  );
}

/// The reaction frame is the [Container] whose fill is the incoming-bubble
/// token and which carries a border. Returns its [BoxDecoration].
BoxDecoration _reactionFrame(WidgetTester tester, Color bubbleIn) {
  final frame = tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.color == bubbleIn && d.border != null);
  return frame;
}

/// Builds a [ReceiverMessageWidget] with safe defaults so each test only
/// overrides the fields it actually exercises.
///
/// Deliberately never defaults `fileType` to `'video'`: that path boots
/// flick_video_player and needs real video controllers the test can't
/// provide.
ReceiverMessageWidget _build({
  String message = '',
  String? file,
  String? fileType,
  bool isBlurred = false,
  bool oneTime = false,
  String? messageType,
  int? messageId = 1,
  int? userId = 2,
}) {
  return ReceiverMessageWidget(
    message: message,
    avatar: '',
    file: file,
    fileType: fileType,
    isBlurred: isBlurred,
    oneTime: oneTime,
    messageId: messageId,
    userId: userId,
    messageType: messageType,
    onUnblur: () {},
    onReply: () {},
    onLongPress: (_) {},
  );
}

void main() {
  testWidgets('renders the plain text message body when not blurred', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_build(message: 'hello world')));
    await tester.pump();

    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('shows the "1" one-time badge on sealed one-time media', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _build(
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
          oneTime: true,
        ),
      ),
    );
    await tester.pump();

    // A sealed one-time send reads as "Photo · view once" (not the generic
    // media card) and carries the "1" badge.
    expect(find.text('Photo · view once'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a sealed one-time REACTION reads as a reaction, not media', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _build(
          file: 'https://example.invalid/reaction.mp4',
          fileType: 'reaction',
          messageType: 'reaction',
          isBlurred: true,
          oneTime: true,
        ),
      ),
    );
    await tester.pump();

    // Fix for the "reaction looks like broken media" report: it must read as a
    // Reaction, never the generic "Click to view the media" card.
    expect(find.text('Reaction · view once'), findsOneWidget);
    expect(find.text('Click to view the media'), findsNothing);
  });

  testWidgets('shows no one-time badge on an ordinary sealed message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _build(
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Click to view the media'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('renders a caption UNDER the media, not above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _build(
          message: 'at the beach',
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
        ),
      ),
    );
    await tester.pump();

    // WhatsApp attaches the caption beneath its media; the sender side already
    // did, the receiver used to render the text first. Compare on-screen Y:
    // the blur placeholder (the media slot) must sit above the caption.
    final mediaY = tester.getTopLeft(find.text('Click to view the media')).dy;
    final captionY = tester.getTopLeft(find.text('at the beach')).dy;

    expect(
      mediaY,
      lessThan(captionY),
      reason: 'media must render above its caption',
    );
  });

  testWidgets('shows the blur placeholder for media when isBlurred is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _build(
          file: 'https://example.invalid/photo.jpg',
          fileType: 'image',
          isBlurred: true,
        ),
      ),
    );
    await tester.pump();

    // The "Click to view the media" affordance is the only thing the
    // patent flow exposes to the receiver pre-tap. If this string moves
    // or the placeholder stops rendering for blurred media, the user
    // has no way to trigger mark-viewed → silent reaction.
    expect(find.text('Click to view the media'), findsOneWidget);
  });

  testWidgets(
    'renders the reaction bubble label when messageType is "reaction"',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _build(
            file: 'https://example.invalid/reaction.mp4',
            fileType: 'reaction',
            messageType: 'reaction',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Reaction'), findsOneWidget);
    },
  );

  testWidgets(
    'syncs local blur state when parent rebuilds with updated isBlurred',
    (tester) async {
      // First mount: blurred media → placeholder visible.
      await tester.pumpWidget(
        _wrap(
          _build(
            file: 'https://example.invalid/photo.jpg',
            fileType: 'image',
            isBlurred: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Click to view the media'), findsOneWidget);

      // Parent rebuilds with isBlurred:false. Per didUpdateWidget, the
      // local _isBlurred must follow. The placeholder should disappear.
      await tester.pumpWidget(
        _wrap(
          _build(
            file: 'https://example.invalid/photo.jpg',
            fileType: 'image',
            isBlurred: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Click to view the media'), findsNothing);
    },
  );

  // Task 3: the reaction frame reads as light-theme (white bubble + hairline
  // border) in light, and stays the original dark olive (#1A1E0A) in dark.
  ReceiverMessageWidget reaction() => _build(
    file: 'https://example.invalid/reaction.mp4',
    fileType: 'reaction',
    messageType: 'reaction',
  );

  testWidgets('light: reaction frame is bubbleIn (white) + hairline border', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(reaction(), theme: AppTheme.light));
    await tester.pump();

    final deco = _reactionFrame(tester, ReactiColors.light.bubbleIn);
    expect(deco.color, const Color(0xFFFFFFFF));
    expect((deco.border as Border).top.color, ReactiColors.light.hairline);
  });

  testWidgets('dark: reaction frame stays the original #1A1E0A (unchanged)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(reaction(), theme: AppTheme.dark));
    await tester.pump();

    // In dark, bubbleIn == the pre-migration olive and there is no border.
    final darkFrame = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == const Color(0xFF1A1E0A));
    expect(darkFrame, isNotEmpty);
    expect(darkFrame.first.border, isNull);
  });
}
