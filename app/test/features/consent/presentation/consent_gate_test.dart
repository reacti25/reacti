// Unit tests for ensureRecordingConsentAndPermission — the DG1 capture-point
// consent + camera-permission gate (F3, the patent path).
//
// The gate is the guard that must pass before mark-viewed / silent recording.
// These tests drive it through every branch with hand-written fakes (the repo
// has no mocking package): already-consented-and-permitted (no dialog),
// cancel, enable→permission-denied, enable→consent-grant-fails, and the happy
// enable→granted+permitted path. ConsentService and CameraPermissionService are
// injected directly so no GetStorage, network, or OS channel is touched.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/consent/consent_copy.dart';
import 'package:reacti_app/features/consent/data/camera_permission_service.dart';
import 'package:reacti_app/features/consent/data/consent_service.dart';
import 'package:reacti_app/features/consent/presentation/consent_gate.dart';

/// ConsentService stand-in with an in-memory consent flag and a scriptable
/// grant outcome — no GetStorage, no network.
class _FakeConsentService extends ConsentService {
  _FakeConsentService({required this.consented, this.grantResult = true});

  bool consented;
  final bool grantResult;
  int grantCalls = 0;

  @override
  bool get hasConsented => consented;

  @override
  Future<bool> grantConsent() async {
    grantCalls++;
    if (grantResult) consented = true;
    return grantResult;
  }
}

/// CameraPermissionService stand-in with scriptable status and request results.
class _FakePermissionService extends CameraPermissionService {
  _FakePermissionService({required this.granted, bool? requestResult})
    : requestResult = requestResult ?? granted;

  bool granted;
  final bool requestResult;
  int requestCalls = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCalls++;
    granted = requestResult;
    return requestResult;
  }
}

void main() {
  /// Pumps a button that runs the gate against the given fakes and records the
  /// boolean result, then taps it. Optionally taps a dialog action by key.
  Future<bool?> runGate(
    WidgetTester tester, {
    required _FakeConsentService consent,
    required _FakePermissionService permission,
    Key? tapAction,
  }) async {
    bool? result;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder:
            (context, _) => MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder:
                      (context) => ElevatedButton(
                        onPressed: () async {
                          result = await ensureRecordingConsentAndPermission(
                            context,
                            consentService: consent,
                            permissionService: permission,
                          );
                        },
                        child: const Text('run'),
                      ),
                ),
              ),
            ),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    if (tapAction != null) {
      await tester.tap(find.byKey(tapAction));
      await tester.pumpAndSettle();
    }

    return result;
  }

  testWidgets(
    'proceeds without a dialog when already consented and permitted',
    (tester) async {
      final consent = _FakeConsentService(consented: true);
      final permission = _FakePermissionService(granted: true);

      final result = await runGate(
        tester,
        consent: consent,
        permission: permission,
      );

      expect(result, isTrue);
      expect(find.text('Enable reactions?'), findsNothing);
      expect(consent.grantCalls, 0);
      expect(permission.requestCalls, 0);
    },
  );

  testWidgets(
    'shows the pop-up with placeholder copy when consent is missing',
    (tester) async {
      final consent = _FakeConsentService(consented: false);
      final permission = _FakePermissionService(granted: false);

      await runGate(tester, consent: consent, permission: permission);

      expect(find.text('Enable reactions?'), findsOneWidget);
      expect(find.text(kConsentCopyPlaceholder), findsOneWidget);
    },
  );

  testWidgets('cancel returns false and records nothing', (tester) async {
    final consent = _FakeConsentService(consented: false);
    final permission = _FakePermissionService(granted: false);

    final result = await runGate(
      tester,
      consent: consent,
      permission: permission,
      tapAction: const Key('consent_gate_cancel'),
    );

    expect(result, isFalse);
    expect(consent.grantCalls, 0);
    expect(permission.requestCalls, 0);
  });

  testWidgets('enable grants consent and permission, then proceeds', (
    tester,
  ) async {
    final consent = _FakeConsentService(consented: false);
    final permission = _FakePermissionService(
      granted: false,
      requestResult: true,
    );

    final result = await runGate(
      tester,
      consent: consent,
      permission: permission,
      tapAction: const Key('consent_gate_enable'),
    );

    expect(result, isTrue);
    expect(consent.grantCalls, 1);
    expect(permission.requestCalls, 1);
  });

  testWidgets('enable but camera permission denied returns false', (
    tester,
  ) async {
    final consent = _FakeConsentService(consented: false);
    final permission = _FakePermissionService(
      granted: false,
      requestResult: false,
    );

    final result = await runGate(
      tester,
      consent: consent,
      permission: permission,
      tapAction: const Key('consent_gate_enable'),
    );

    expect(result, isFalse);
    expect(consent.grantCalls, 1);
    expect(permission.requestCalls, 1);
  });

  testWidgets(
    'enable but consent grant fails returns false, skips permission',
    (tester) async {
      final consent = _FakeConsentService(consented: false, grantResult: false);
      final permission = _FakePermissionService(granted: false);

      final result = await runGate(
        tester,
        consent: consent,
        permission: permission,
        tapAction: const Key('consent_gate_enable'),
      );

      expect(result, isFalse);
      expect(consent.grantCalls, 1);
      expect(permission.requestCalls, 0);
    },
  );

  testWidgets('already consented but permission revoked shows the pop-up', (
    tester,
  ) async {
    // Covers the "consent given earlier, OS camera later revoked" case — the
    // synchronous mirror alone is not enough; the live permission check gates.
    final consent = _FakeConsentService(consented: true);
    final permission = _FakePermissionService(
      granted: false,
      requestResult: true,
    );

    final result = await runGate(
      tester,
      consent: consent,
      permission: permission,
      tapAction: const Key('consent_gate_enable'),
    );

    expect(result, isTrue);
    // Consent already on file → no re-grant; only permission is requested.
    expect(consent.grantCalls, 0);
    expect(permission.requestCalls, 1);
  });
}
