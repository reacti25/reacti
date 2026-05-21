// Widget tests for SenderTextBubble — the text portion of a sent chat
// bubble, extracted from SenderMessageWidget so it can be tested in
// isolation. Uses the shared pumpInApp harness.

import 'package:reacti_app/features/chat/presentation/widget/sender_text_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('SenderTextBubble', () {
    testWidgets('renders the message text and timestamp', (tester) async {
      await pumpInApp(
        tester,
        const SenderTextBubble(
          message: 'hello world',
          time: '9:05 AM',
          isLocal: false,
        ),
      );

      expect(find.text('hello world'), findsOneWidget);
      expect(find.text('9:05 AM'), findsOneWidget);
    });

    testWidgets('a delivered (non-local) message shows the check indicator', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const SenderTextBubble(message: 'hi', time: '9:05 AM', isLocal: false),
      );

      // A confirmed message shows a check mark, not a spinner.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an in-flight (local) message shows a spinner instead', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const SenderTextBubble(message: 'hi', time: '9:05 AM', isLocal: true),
      );

      // While uploading, the indicator is a spinner, not the check mark.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('renders with a null timestamp', (tester) async {
      await pumpInApp(
        tester,
        const SenderTextBubble(message: 'no time', isLocal: false),
      );

      expect(find.text('no time'), findsOneWidget);
    });
  });
}
