// Widget test for the analytics opt-out toggle (Phase 4 — the one permitted
// user-facing addition). Toggling the switch must persist the opt-out via
// AnalyticsConsent.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reacti_app/analytics/analytics_consent.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/analytics_settings/presentation/analytics_settings_screen.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../../support/test_storage.dart';

Widget _wrap() => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (context, _) => const MaterialApp(home: AnalyticsSettingsScreen()),
);

void main() {
  late AnalyticsConsent consent;

  setUp(() async {
    await initTestGetStorage();
    final storage = locator.get<GetStorage>();
    await storage.remove(kKeyAnalyticsOptOut);
    if (locator.isRegistered<AnalyticsConsent>()) {
      locator.unregister<AnalyticsConsent>();
    }
    consent = AnalyticsConsent(storage: storage);
    locator.registerSingleton<AnalyticsConsent>(consent);
  });

  tearDown(() {
    if (locator.isRegistered<AnalyticsConsent>()) {
      locator.unregister<AnalyticsConsent>();
    }
  });

  testWidgets('starts ON (opted in) and toggling OFF opts the user out', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    final sw = find.byKey(const Key('analytics_optout_switch'));
    expect(tester.widget<SwitchListTile>(sw).value, isTrue); // opted in
    expect(consent.isOptedOut, isFalse);

    await tester.tap(sw);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    expect(consent.isOptedOut, isTrue); // persisted opt-out
  });
}
