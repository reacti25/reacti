// Widget test for AppearanceOptions — the shared System/Light/Dark chooser
// used by both the first-run step and the settings screen.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/theme/appearance_options.dart';
import 'package:reacti_app/theme/theme_controller.dart';

import '../support/test_storage.dart';

void main() {
  late ThemeController controller;

  // GetStorage init must run outside the testWidgets fake-async zone, or the
  // disk-backed init future never completes.
  setUp(() async {
    await initTestGetStorage();
    final storage = locator.get<GetStorage>();
    await storage.remove(kKeyThemeMode);
    controller = ThemeController(storage: storage);
  });

  Widget wrap() => ScreenUtilInit(
    designSize: const Size(375, 812),
    builder:
        (_, __) => ChangeNotifierProvider<ThemeController>.value(
          value: controller,
          child: const MaterialApp(home: Scaffold(body: AppearanceOptions())),
        ),
  );

  testWidgets('tapping a mode updates the controller and moves the check', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(controller.themeMode, ThemeMode.system);

    await tester.tap(find.byKey(const Key('theme_mode_dark')));
    await tester.pump();

    expect(controller.themeMode, ThemeMode.dark);
    // The check now sits on the Dark row and nowhere else.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('theme_mode_dark')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });
}
