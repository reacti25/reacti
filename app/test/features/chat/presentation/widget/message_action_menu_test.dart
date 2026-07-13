// Widget tests for showMessageActionMenu — the WhatsApp-style long-press
// action menu shared by the one-to-one and group chat screens.

import 'package:reacti_app/features/chat/presentation/widget/message_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps a single button that opens the menu with [actions] when tapped,
  /// then taps it and settles the open animation. Kept local (not the shared
  /// harness) because the menu must be launched from a real button context so
  /// its [Navigator] route pushes and pops correctly.
  Future<void> openMenu(
    WidgetTester tester,
    List<MessageAction> actions,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder:
                      (context) => Center(
                        child: ElevatedButton(
                          onPressed:
                              () => showMessageActionMenu(
                                context,
                                tapPosition: const Offset(100, 300),
                                actions: actions,
                              ),
                          child: const Text('open'),
                        ),
                      ),
                ),
              ),
            ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showMessageActionMenu', () {
    testWidgets('renders every action label', (tester) async {
      await openMenu(tester, [
        MessageAction(icon: Icons.reply_rounded, label: 'Reply', onTap: () {}),
        MessageAction(icon: Icons.copy_rounded, label: 'Copy', onTap: () {}),
        MessageAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          isDestructive: true,
          onTap: () {},
        ),
      ]);

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('tapping an action runs its callback and dismisses the menu', (
      tester,
    ) async {
      var tapped = false;
      await openMenu(tester, [
        MessageAction(
          icon: Icons.reply_rounded,
          label: 'Reply',
          onTap: () => tapped = true,
        ),
      ]);

      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(find.text('Reply'), findsNothing); // menu closed
    });

    testWidgets('destructive action is tinted with the error colour', (
      tester,
    ) async {
      await openMenu(tester, [
        MessageAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          isDestructive: true,
          onTap: () {},
        ),
      ]);

      final errorColor =
          Theme.of(tester.element(find.text('Delete'))).colorScheme.error;
      final label = tester.widget<Text>(find.text('Delete'));
      expect(label.style?.color, errorColor);
    });
  });
}
