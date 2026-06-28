// Unit + widget tests for the centralised sent-message status indicator.
//
// Covers the pure tickStatusFor mapping (including the reciprocal
// read-receipts suppression) and the three rendered states of
// MessageStatusTicks, plus the reaction grey→green dot.

import 'package:reacti_app/features/chat/presentation/widget/message_status_ticks.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('tickStatusFor', () {
    test('an in-flight local message is sending', () {
      expect(
        tickStatusFor(isLocal: true, isSeen: true, readReceiptsEnabled: true),
        MessageTickStatus.sending,
      );
    });

    test('seen only when seen AND read receipts on', () {
      expect(
        tickStatusFor(isLocal: false, isSeen: true, readReceiptsEnabled: true),
        MessageTickStatus.seen,
      );
    });

    test('receipts off suppresses seen (reciprocal) → sent', () {
      expect(
        tickStatusFor(isLocal: false, isSeen: true, readReceiptsEnabled: false),
        MessageTickStatus.sent,
      );
    });

    test('not seen yet → sent', () {
      expect(
        tickStatusFor(isLocal: false, isSeen: false, readReceiptsEnabled: true),
        MessageTickStatus.sent,
      );
    });
  });

  group('MessageStatusTicks', () {
    testWidgets('sending shows a spinner only', (tester) async {
      await pumpInApp(
        tester,
        const MessageStatusTicks(status: MessageTickStatus.sending),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('sent shows a single check', (tester) async {
      await pumpInApp(
        tester,
        const MessageStatusTicks(status: MessageTickStatus.sent),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('seen shows the double check', (tester) async {
      await pumpInApp(
        tester,
        const MessageStatusTicks(status: MessageTickStatus.seen),
      );
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('ReactionSeenDot', () {
    testWidgets('is grey when not seen, green when seen', (tester) async {
      await pumpInApp(tester, const ReactionSeenDot(seen: false));
      var dot = tester.widget<Container>(
        find.descendant(
          of: find.byType(ReactionSeenDot),
          matching: find.byType(Container),
        ),
      );
      expect(
        (dot.decoration as BoxDecoration).color,
        isNot(AppColors.allPrimaryColor),
      );

      await pumpInApp(tester, const ReactionSeenDot(seen: true));
      dot = tester.widget<Container>(
        find.descendant(
          of: find.byType(ReactionSeenDot),
          matching: find.byType(Container),
        ),
      );
      expect(
        (dot.decoration as BoxDecoration).color,
        AppColors.allPrimaryColor,
      );
    });
  });
}
