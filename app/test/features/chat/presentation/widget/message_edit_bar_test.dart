// Widget tests for MessageEditBar — the composer shown while editing a message.

import 'package:reacti_app/features/chat/presentation/widget/message_edit_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('MessageEditBar', () {
    testWidgets('renders the header and prefills the field', (tester) async {
      await pumpInApp(
        tester,
        MessageEditBar(
          initialText: 'hello world',
          onSubmit: (_) {},
          onCancel: () {},
        ),
      );

      expect(find.text('Edit message'), findsOneWidget);
      expect(find.text('hello world'), findsOneWidget);
    });

    testWidgets('submit hands back the trimmed text', (tester) async {
      String? submitted;
      await pumpInApp(
        tester,
        MessageEditBar(
          initialText: 'hi',
          onSubmit: (text) => submitted = text,
          onCancel: () {},
        ),
      );

      await tester.enterText(find.byType(TextField), '  edited value  ');
      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pump();

      expect(submitted, 'edited value');
    });

    testWidgets('empty text does not submit', (tester) async {
      var submitCount = 0;
      await pumpInApp(
        tester,
        MessageEditBar(
          initialText: 'hi',
          onSubmit: (_) => submitCount++,
          onCancel: () {},
        ),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pump();

      expect(submitCount, 0);
    });

    testWidgets('close invokes onCancel', (tester) async {
      var cancelled = false;
      await pumpInApp(
        tester,
        MessageEditBar(
          initialText: 'hi',
          onSubmit: (_) {},
          onCancel: () => cancelled = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cancelled, isTrue);
    });
  });
}
