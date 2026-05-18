// Widget tests for DeleteMessageSheet — the delete-message confirmation
// bottom sheet shown from InboxScreen.

import 'package:achiar_expert_app/features/chat/presentation/widget/delete_message_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('DeleteMessageSheet', () {
    testWidgets('renders the delete row', (tester) async {
      await pumpInApp(tester, DeleteMessageSheet(onConfirm: () {}));

      expect(find.text('Delete this message'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('invokes onConfirm when the row is tapped', (tester) async {
      var confirmed = false;

      await pumpInApp(
        tester,
        DeleteMessageSheet(onConfirm: () => confirmed = true),
      );

      await tester.tap(find.byType(InkWell));
      expect(confirmed, isTrue);
    });
  });
}
