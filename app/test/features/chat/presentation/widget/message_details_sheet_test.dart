// Widget tests for MessageDetailsSheet — the message-info bottom sheet shown
// from the long-press action menu.

import 'package:reacti_app/features/chat/presentation/widget/message_details_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('MessageDetailsSheet', () {
    testWidgets('shows the sent time and a status row for own messages', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const MessageDetailsSheet(sentAt: '2 mins ago', statusLabel: 'Seen'),
      );

      expect(find.text('Message info'), findsOneWidget);
      expect(find.text('2 mins ago'), findsOneWidget);
      expect(find.text('Status: '), findsOneWidget);
      expect(find.text('Seen'), findsOneWidget);
    });

    testWidgets('hides the status row for received messages (null status)', (
      tester,
    ) async {
      await pumpInApp(tester, const MessageDetailsSheet(sentAt: '5 mins ago'));

      expect(find.text('5 mins ago'), findsOneWidget);
      expect(find.text('Status: '), findsNothing);
    });
  });
}
