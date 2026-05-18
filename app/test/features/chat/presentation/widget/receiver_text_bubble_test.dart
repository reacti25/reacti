// Widget tests for ReceiverTextBubble — the text portion of a received
// chat bubble, extracted from ReceiverMessageWidget. Uses the shared
// pumpInApp harness.

import 'package:achiar_expert_app/features/chat/presentation/widget/receiver_text_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('ReceiverTextBubble', () {
    testWidgets('renders the message text and timestamp', (tester) async {
      await pumpInApp(
        tester,
        const ReceiverTextBubble(
          message: 'incoming message',
          time: '10:30 AM',
          hasFile: false,
        ),
      );

      expect(find.text('incoming message'), findsOneWidget);
      expect(find.text('10:30 AM'), findsOneWidget);
    });

    testWidgets('renders when media follows below the text', (tester) async {
      await pumpInApp(
        tester,
        const ReceiverTextBubble(
          message: 'caption',
          time: '10:30 AM',
          hasFile: true,
        ),
      );

      expect(find.text('caption'), findsOneWidget);
    });

    testWidgets('renders with a null timestamp', (tester) async {
      await pumpInApp(
        tester,
        const ReceiverTextBubble(message: 'no time', hasFile: false),
      );

      expect(find.text('no time'), findsOneWidget);
    });
  });
}
