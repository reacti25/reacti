// Widget tests for the "edited" label on the sender/receiver text bubbles.

import 'package:reacti_app/features/chat/presentation/widget/receiver_text_bubble.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_text_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('edited label', () {
    testWidgets('SenderTextBubble shows "edited" only when isEdited', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const SenderTextBubble(message: 'hi', isLocal: false, time: 'now'),
      );
      expect(find.text('edited'), findsNothing);

      await pumpInApp(
        tester,
        const SenderTextBubble(
          message: 'hi',
          isLocal: false,
          time: 'now',
          isEdited: true,
        ),
      );
      expect(find.text('edited'), findsOneWidget);
    });

    testWidgets('ReceiverTextBubble shows "edited" only when isEdited', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const ReceiverTextBubble(message: 'hi', hasFile: false, time: 'now'),
      );
      expect(find.text('edited'), findsNothing);

      await pumpInApp(
        tester,
        const ReceiverTextBubble(
          message: 'hi',
          hasFile: false,
          time: 'now',
          isEdited: true,
        ),
      );
      expect(find.text('edited'), findsOneWidget);
    });
  });
}
