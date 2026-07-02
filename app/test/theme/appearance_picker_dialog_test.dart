// Task 5: the first-run appearance picker.
//
// - shouldPromptAppearance gates the dialog to a fresh sign-up, shown once.
// - "Use this" keeps the live-applied choice; "Skip" reverts to system. Both
//   mark the prompt as shown so it never reappears.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/theme/appearance_picker_dialog.dart';
import 'package:reacti_app/theme/theme_controller.dart';

import '../support/test_storage.dart';

void main() {
  late GetStorage storage;
  late ThemeController controller;

  setUp(() async {
    await initTestGetStorage();
    storage = locator.get<GetStorage>();
    await storage.remove(kKeyJustSignedUp);
    await storage.remove(kKeyAppearanceAsked);
    await storage.remove(kKeyThemeMode);
    controller = ThemeController(storage: storage);
  });

  group('shouldPromptAppearance', () {
    test('true only after a fresh sign-up and not yet asked', () async {
      await storage.write(kKeyJustSignedUp, true);
      expect(shouldPromptAppearance(storage), isTrue);
    });

    test('false for a returning login (no fresh-signup flag)', () {
      expect(shouldPromptAppearance(storage), isFalse);
    });

    test('false once the prompt has already been shown', () async {
      await storage.write(kKeyJustSignedUp, true);
      await storage.write(kKeyAppearanceAsked, true);
      expect(shouldPromptAppearance(storage), isFalse);
    });
  });

  group('showAppearancePickerDialog', () {
    // Provider sits ABOVE MaterialApp so the dialog (pushed onto the app's
    // overlay) can resolve the ThemeController.
    Widget host() => ChangeNotifierProvider<ThemeController>.value(
      value: controller,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder:
                      (ctx) => Center(
                        child: ElevatedButton(
                          onPressed: () => showAppearancePickerDialog(ctx),
                          child: const Text('open'),
                        ),
                      ),
                ),
              ),
            ),
      ),
    );

    testWidgets('"Use this" keeps the tapped choice and marks asked', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme_mode_light')));
      await tester.pump();
      expect(controller.themeMode, ThemeMode.light); // applied live

      await tester.tap(find.byKey(const Key('appearance_use_this')));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.light);
      expect(storage.read(kKeyAppearanceAsked), true);
    });

    testWidgets('"Skip" reverts to system and marks asked', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme_mode_dark')));
      await tester.pump();
      expect(controller.themeMode, ThemeMode.dark);

      await tester.tap(find.byKey(const Key('appearance_skip')));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.system);
      expect(storage.read(kKeyAppearanceAsked), true);
    });
  });
}
