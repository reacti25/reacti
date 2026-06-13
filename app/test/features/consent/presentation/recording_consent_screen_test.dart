// Widget tests for RecordingConsentScreen — the one-time silent-recording
// consent shown at the end of registration (DG1 F2).
//
// The screen resolves ConsentService from the get_it locator, so each test
// swaps in a fake that records whether grantConsent() was called instead of
// hitting the network. Navigation goes through NavigationService's global
// navigatorKey; the test MaterialApp resolves Routes.navigationScreen to a
// placeholder so the "enter the app" transition can be observed.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reacti_app/features/consent/consent_copy.dart';
import 'package:reacti_app/features/consent/data/consent_service.dart';
import 'package:reacti_app/features/consent/presentation/recording_consent_screen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';

import '../../../support/test_storage.dart';

/// ConsentService stand-in that records whether [grantConsent] ran, without
/// touching the network.
class _FakeConsentService extends ConsentService {
  _FakeConsentService(GetStorage storage) : super(storage: storage);

  /// Whether [grantConsent] has been invoked.
  bool grantCalled = false;

  @override
  Future<bool> grantConsent() async {
    grantCalled = true;
    return true;
  }
}

/// Wraps the consent screen in the ScreenUtil + MaterialApp shell it needs,
/// resolving [Routes.navigationScreen] to a recognisable placeholder so the
/// post-decision navigation is observable.
Widget _wrap() => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder:
      (context, _) => MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: const RecordingConsentScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == Routes.navigationScreen) {
            return MaterialPageRoute(
              settings: settings,
              builder:
                  (_) => const Scaffold(body: Text('nav-screen-placeholder')),
            );
          }
          return null;
        },
      ),
);

void main() {
  late _FakeConsentService fakeConsent;

  setUp(() async {
    await initTestGetStorage();
    // Swap the locator's ConsentService for the call-recording fake.
    if (locator.isRegistered<ConsentService>()) {
      locator.unregister<ConsentService>();
    }
    fakeConsent = _FakeConsentService(locator.get<GetStorage>());
    locator.registerSingleton<ConsentService>(fakeConsent);
    // Reset the navigator key so each test pumps a fresh navigator.
    NavigationService.navigatorKey = GlobalKey<NavigatorState>();
  });

  testWidgets('shows the placeholder consent copy (pending lawyer)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text(kConsentCopyPlaceholder), findsOneWidget);
  });

  testWidgets('accept records consent and enters the app', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    await tester.tap(find.byKey(const Key('consent_accept_button')));
    await tester.pumpAndSettle();

    expect(fakeConsent.grantCalled, isTrue);
    expect(find.text('nav-screen-placeholder'), findsOneWidget);
  });

  testWidgets('decline enters the app without recording consent', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    await tester.tap(find.byKey(const Key('consent_decline_button')));
    await tester.pumpAndSettle();

    expect(fakeConsent.grantCalled, isFalse);
    expect(find.text('nav-screen-placeholder'), findsOneWidget);
  });
}
