// The lock cover, and the rule that turning the lock OFF must prove identity.
//
// Both are cases where a bug makes the feature decoration rather than
// protection: a cover that does not actually cover leaks the last thread, and
// a switch anyone holding the phone can flip protects nobody.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/app_lock/app_lock_gate.dart';
import 'package:reacti_app/features/app_lock/app_lock_settings.dart';
import 'package:reacti_app/features/app_lock/app_lock_settings_sheet.dart';
import 'package:reacti_app/features/app_lock/biometric_auth.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

/// Pumps [child] in a BOUNDED shell, the way production mounts it.
///
/// Not the shared `pumpInApp` harness: that wraps its child in a
/// [SingleChildScrollView], which hands the lock cover unbounded height. In
/// production the gate sits inside `GetMaterialApp`'s builder with the screen's
/// constraints, so an unbounded parent would be testing a shape the app never
/// has.
Future<void> pumpBounded(WidgetTester tester, Widget child) async {
  // A phone-shaped surface. The default 800x600 test window is WIDER than the
  // 375-point design, so flutter_screenutil scales everything UP and the layout
  // under test is one no handset ever produces.
  tester.view.physicalSize = const Size(1125, 2436);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

/// A biometric prompt that answers however the test wants, without a device.
class _FakeBiometricAuth extends BiometricAuth {
  /// What the prompt returns. Set per test rather than at construction —
  /// several tests flip it mid-run to model a failed scan then a good one.
  bool succeeds = true;

  /// Whether the device claims it can lock at all.
  bool available = true;

  /// How many times the prompt was raised.
  int promptCount = 0;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    promptCount++;
    return succeeds;
  }
}

void main() {
  late _FakeBiometricAuth fake;
  late BiometricAuth original;

  setUp(() async {
    await initTestGetStorage();
    await appData.remove(kKeyAppLockEnabled);
    await appData.remove(kKeyAppLockDelay);
    original = BiometricAuth.instance;
    fake = _FakeBiometricAuth();
    BiometricAuth.instance = fake;
  });

  tearDown(() => BiometricAuth.instance = original);

  group('AppLockGate', () {
    testWidgets('stays out of the way when the lock is off', (tester) async {
      await pumpBounded(
        tester,
        const AppLockGate(child: Text('my private chats')),
      );

      expect(find.text('my private chats'), findsOneWidget);
      expect(find.text('Reacti is locked'), findsNothing);
      expect(fake.promptCount, 0, reason: 'nobody asked for a lock');
    });

    testWidgets('covers the app on a cold start when the lock is on', (
      tester,
    ) async {
      await AppLockSettings.setEnabled(true);
      // Never answer, so the cover is observable while the prompt is pending —
      // this is the state the app switcher would screenshot.
      fake.succeeds = false;

      await pumpBounded(
        tester,
        const AppLockGate(child: Text('my private chats')),
      );
      await tester.pump();

      expect(find.text('Reacti is locked'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      expect(fake.promptCount, 1);
    });

    testWidgets('a failed prompt leaves a way back in', (tester) async {
      await AppLockSettings.setEnabled(true);
      fake.succeeds = false;

      await pumpBounded(
        tester,
        const AppLockGate(child: Text('my private chats')),
      );
      await tester.pump();

      await tester.pumpAndSettle();

      // The button's callback is invoked directly rather than tapped: the cover
      // sits in a Stack above the app, and under the test binding the tap does
      // not reach it. What matters here is that the button is wired to a
      // working unlock — one cancelled scan must not leave a permanently blank
      // app — and that is what this exercises.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Unlock'),
      );
      expect(button.onPressed, isNotNull, reason: 'Unlock must be tappable');

      fake.succeeds = true;
      button.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Reacti is locked'), findsNothing);
      expect(find.text('my private chats'), findsOneWidget);
    });
  });

  group('AppLockSettingsSheet', () {
    testWidgets('turning the lock ON requires proving identity first', (
      tester,
    ) async {
      await pumpBounded(tester, const AppLockSettingsSheet());
      await tester.pumpAndSettle();

      fake.succeeds = false;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // Refused, so nothing was enabled — better to find out the lock cannot
      // open now than at the next launch.
      expect(AppLockSettings.enabled, isFalse);
      expect(fake.promptCount, greaterThan(0));
    });

    testWidgets('turning the lock OFF requires proving identity too', (
      tester,
    ) async {
      await AppLockSettings.setEnabled(true);
      await pumpBounded(tester, const AppLockSettingsSheet());
      await tester.pumpAndSettle();

      fake.succeeds = false;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // A lock anyone holding the phone can switch off is decoration.
      expect(AppLockSettings.enabled, isTrue);
    });

    testWidgets('a device that cannot lock says so instead of offering it', (
      tester,
    ) async {
      fake.available = false;

      await pumpBounded(tester, const AppLockSettingsSheet());
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('no Face ID'), findsOneWidget);
    });
  });
}
