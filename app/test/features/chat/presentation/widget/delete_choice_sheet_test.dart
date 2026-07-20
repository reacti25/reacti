// Widget tests for DeleteChoiceSheet — the "Delete for me" / "Delete for
// everyone" chooser.

import 'package:reacti_app/features/chat/presentation/widget/delete_choice_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('DeleteChoiceSheet', () {
    testWidgets('offers both options when for-everyone is available', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        DeleteChoiceSheet(onDeleteForMe: () {}, onDeleteForEveryone: () {}),
      );

      expect(find.text('Delete for me'), findsOneWidget);
      expect(find.text('Delete for everyone'), findsOneWidget);
    });

    testWidgets('hides for-everyone when not provided', (tester) async {
      await pumpInApp(tester, DeleteChoiceSheet(onDeleteForMe: () {}));

      expect(find.text('Delete for me'), findsOneWidget);
      expect(find.text('Delete for everyone'), findsNothing);
    });

    testWidgets('tapping a row invokes its callback', (tester) async {
      var forMe = false;
      var forEveryone = false;
      await pumpInApp(
        tester,
        DeleteChoiceSheet(
          onDeleteForMe: () => forMe = true,
          onDeleteForEveryone: () => forEveryone = true,
        ),
      );

      await tester.tap(find.text('Delete for me'));
      expect(forMe, isTrue);

      await tester.tap(find.text('Delete for everyone'));
      expect(forEveryone, isTrue);
    });
  });
}
