// Widget tests for the pre-login welcome screen (T4 of
// docs/PLAN-onboarding-walkthrough-2026-08-15.md), which replaced the
// three-slide onboarding carousel.
//
// The only real logic here is the first-run flag: if "Get started" fails to
// clear kKeyIsFirstTime the app shows this screen on every launch forever,
// and if it clears the flag when opened from login as an explainer, a user
// who has not signed up yet silently loses their first-run routing.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/onboard/presentation/welcome_screen.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

/// Pumps [child] in the minimal shell the screen needs (ScreenUtil for the
/// `.h`/`.w` extensions, MaterialApp for theme and Navigator).
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    await initTestGetStorage();
    await appData.remove(kKeyIsFirstTime);
  });

  testWidgets('shows the one-line pitch and a way in', (tester) async {
    await _pump(tester, const WelcomeScreen());

    expect(find.textContaining('real reaction'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('opened from login it reads as an explainer, not a gate', (
    tester,
  ) async {
    await _pump(tester, const WelcomeScreen(fromLogin: true));

    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('from login it leaves the first-run flag alone', (tester) async {
    await appData.write(kKeyIsFirstTime, true);

    await _pump(tester, const WelcomeScreen(fromLogin: true));
    await tester.tap(find.text('Got it'));
    await tester.pump();

    // Consuming the flag here would drop a not-yet-signed-up user out of
    // first-run routing just for re-reading the pitch.
    expect(appData.read(kKeyIsFirstTime), isTrue);
  });
}
