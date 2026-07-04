// Widget tests for DeleteMessageSheet — the delete-message confirmation
// bottom sheet shown from InboxScreen.

import 'package:reacti_app/features/chat/presentation/widget/delete_message_sheet.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

    // The label was pinned to black — invisible on the themed dark sheet.
    // It now reads onSurface, legible in both modes.
    Future<Color?> labelColor(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder:
              (_, _) => MaterialApp(
                theme: theme,
                home: Scaffold(body: DeleteMessageSheet(onConfirm: () {})),
              ),
        ),
      );
      await tester.pump();
      return tester.widget<Text>(find.text('Delete this message')).style?.color;
    }

    testWidgets('label uses onSurface in light (legible)', (tester) async {
      expect(
        await labelColor(tester, AppTheme.light),
        AppTheme.light.colorScheme.onSurface,
      );
    });

    testWidgets('label uses onSurface in dark (legible, not black)', (
      tester,
    ) async {
      final color = await labelColor(tester, AppTheme.dark);
      expect(color, AppTheme.dark.colorScheme.onSurface);
      expect(color, isNot(const Color(0xFF000000)));
    });
  });
}
