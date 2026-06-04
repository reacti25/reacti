// Widget tests for ScrollToBottomButton — the floating "jump to newest"
// button shared by InboxScreen and GroupInboxScreen.

import 'package:reacti_app/features/chat/presentation/widget/scroll_to_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('ScrollToBottomButton', () {
    testWidgets('shows the downward arrow icon', (tester) async {
      await pumpInApp(tester, ScrollToBottomButton(onPressed: () {}));

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var pressed = false;

      await pumpInApp(
        tester,
        ScrollToBottomButton(onPressed: () => pressed = true),
      );

      await tester.tap(find.byType(FloatingActionButton));
      expect(pressed, isTrue);
    });
  });
}
