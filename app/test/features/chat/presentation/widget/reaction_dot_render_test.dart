// Pins the sender-side reaction "watched" dot rendering across its states:
//   - in-flight (isLocal)      -> spinner, no dot
//   - sent, not yet watched    -> grey ReactionSeenDot
//   - watched (isSeen + on)    -> green ReactionSeenDot
//   - receipts off             -> stays grey even if isSeen
//
// The reaction renders a video; the fake platform resolves its controller with
// no timers, and the trailing pump drains the controls' 5s auto-hide timer.

import 'package:reacti_app/features/chat/presentation/widget/message_status_ticks.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../support/fake_video_player_platform.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
);

SenderMessageWidget _reaction({
  required bool isLocal,
  required bool isSeen,
  bool readReceiptsEnabled = true,
}) => SenderMessageWidget(
  message: '',
  time: 'now',
  file: 'fake/reaction.mp4',
  mediaType: 'reaction',
  messageType: 'reaction',
  isLocal: isLocal,
  isSeen: isSeen,
  readReceiptsEnabled: readReceiptsEnabled,
  messageId: 1,
  onLongPressDelete: () {},
  onReply: () {},
);

Color _dotColor(WidgetTester tester) {
  final c = tester.widget<Container>(
    find.descendant(
      of: find.byType(ReactionSeenDot),
      matching: find.byType(Container),
    ),
  );
  return (c.decoration as BoxDecoration).color!;
}

void main() {
  late VideoPlayerPlatform original;

  setUp(() => original = installFakeVideoPlayerPlatform());
  tearDown(() => VideoPlayerPlatform.instance = original);

  testWidgets('sent reaction, not yet watched -> grey dot', (tester) async {
    await tester.pumpWidget(_wrap(_reaction(isLocal: false, isSeen: false)));
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(ReactionSeenDot), findsOneWidget);
    expect(_dotColor(tester), isNot(AppColors.allPrimaryColor));
  });

  testWidgets('watched reaction -> green dot', (tester) async {
    await tester.pumpWidget(_wrap(_reaction(isLocal: false, isSeen: true)));
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(ReactionSeenDot), findsOneWidget);
    expect(_dotColor(tester), AppColors.allPrimaryColor);
  });

  testWidgets('receipts off -> grey even when watched', (tester) async {
    await tester.pumpWidget(
      _wrap(_reaction(isLocal: false, isSeen: true, readReceiptsEnabled: false)),
    );
    await tester.pump(const Duration(seconds: 6));

    expect(_dotColor(tester), isNot(AppColors.allPrimaryColor));
  });

  testWidgets('in-flight reaction -> spinner, no dot', (tester) async {
    await tester.pumpWidget(_wrap(_reaction(isLocal: true, isSeen: false)));
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(ReactionSeenDot), findsNothing);
    expect(find.byType(MessageStatusTicks), findsOneWidget);
  });
}
