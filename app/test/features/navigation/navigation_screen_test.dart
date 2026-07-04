// Widget tests for the bottom-navigation active-state (Task 2).
//
// Light mode: the active tab is a filled `brandFill` pill (with `onBrandFill`
// icon/label); inactive tabs are transparent. Dark mode is unchanged — it
// renders no pill container at all, so its appearance stays byte-for-byte
// identical to before. The item is pumped in isolation (NavBarItem) to avoid
// booting the tab bodies' realtime/network timers.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/navigation/presentation/navigation_screen.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';

void main() {
  Future<void> pumpItem(
    WidgetTester tester, {
    required ThemeData theme,
    required bool selected,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Row(
                  children: [
                    NavBarItem(
                      icon: Assets.icons.chat,
                      label: 'Chat',
                      selected: selected,
                      onTap: onTap ?? () {},
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
    await tester.pump();
  }

  Color? pillColor(WidgetTester tester) {
    final c = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    return (c.decoration as BoxDecoration?)?.color;
  }

  testWidgets('light selected: filled brandFill pill', (tester) async {
    await pumpItem(tester, theme: AppTheme.light, selected: true);
    expect(pillColor(tester), ReactiColors.light.brandFill);
  });

  testWidgets('light unselected: transparent pill', (tester) async {
    await pumpItem(tester, theme: AppTheme.light, selected: false);
    expect(pillColor(tester), Colors.transparent);
  });

  testWidgets('light: tapping the item fires onTap', (tester) async {
    var taps = 0;
    await pumpItem(
      tester,
      theme: AppTheme.light,
      selected: false,
      onTap: () => taps++,
    );
    await tester.tap(find.text('Chat'));
    expect(taps, 1);
  });

  testWidgets('dark: no pill container (appearance unchanged)', (tester) async {
    await pumpItem(tester, theme: AppTheme.dark, selected: true);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
