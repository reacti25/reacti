// Unit tests for ThemeController — the persisted appearance selector wired
// into GetMaterialApp's themeMode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/theme/theme_controller.dart';

import '../support/test_storage.dart';

void main() {
  late GetStorage storage;

  setUp(() async {
    await initTestGetStorage();
    storage = locator.get<GetStorage>();
    await storage.remove(kKeyThemeMode);
  });

  test('defaults to system when nothing is stored', () {
    expect(ThemeController(storage: storage).themeMode, ThemeMode.system);
  });

  test('loads a previously persisted choice', () async {
    await storage.write(kKeyThemeMode, 'dark');
    expect(ThemeController(storage: storage).themeMode, ThemeMode.dark);
  });

  test('setThemeMode persists and notifies', () async {
    final controller = ThemeController(storage: storage);
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setThemeMode(ThemeMode.light);

    expect(controller.themeMode, ThemeMode.light);
    expect(storage.read(kKeyThemeMode), 'light');
    expect(notified, 1);
    // A fresh controller reads back the same choice.
    expect(ThemeController(storage: storage).themeMode, ThemeMode.light);
  });

  test('setting the current mode is a no-op (no notify, no write churn)', () {
    final controller = ThemeController(storage: storage); // system
    var notified = 0;
    controller.addListener(() => notified++);

    controller.setThemeMode(ThemeMode.system);

    expect(notified, 0);
  });
}
