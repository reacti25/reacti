// Widget tests for the Feature 8c just-in-time camera/mic primer.
//
// Pins: the one-time explanation dialog shows once and sets
// kKeyCamMicPrimerShown; a primed user skips straight to the permission
// request; a denial surfaces the "allow them in Settings" message and returns
// false. Also the gate on opening sealed media (allowsOpening): open with
// camera and microphone, closed without either, open when the status cannot
// be read. The permission_handler channel is mocked so `.request()` resolves
// without a real platform.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/cam_mic_primer.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/test_storage.dart';

void main() {
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  /// How many times the OS was asked (as opposed to only read).
  var requests = 0;

  /// Mocks the permission channel to grant or deny whatever is requested;
  /// [microphone] answers for the microphone alone when given.
  void mockPermissions({required bool granted, bool? microphone}) {
    requests = 0;
    // PermissionStatus: 0 = denied, 1 = granted.
    int status(int permission) =>
        (permission == Permission.microphone.value
                ? microphone ?? granted
                : granted)
            ? 1
            : 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'requestPermissions') {
            requests++;
            final requested = (call.arguments as List).cast<int>();
            return {for (final p in requested) p: status(p)};
          }
          if (call.method == 'checkPermissionStatus') {
            return status(call.arguments as int);
          }
          return null;
        });
  }

  setUp(() async {
    await initTestGetStorage();
  });

  tearDown(() {
    appData.remove(kKeyCamMicPrimerShown);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  Widget host(Future<void> Function(BuildContext) onTap) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder:
            (context) => ElevatedButton(
              key: const Key('go'),
              onPressed: () => onTap(context),
              child: const Text('go'),
            ),
      ),
    ),
  );

  testWidgets('shows the primer once, sets the flag, and grants', (
    tester,
  ) async {
    mockPermissions(granted: true);
    bool? granted;
    await tester.pumpWidget(
      host((ctx) async => granted = await CamMicPrimer.ensure(ctx)),
    );

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();

    expect(
      find.text(
        'Reacti needs camera and microphone only when you open a Reacti.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(appData.read(kKeyCamMicPrimerShown), true);
    expect(granted, true);
  });

  testWidgets('skips the dialog when already primed', (tester) async {
    await appData.write(kKeyCamMicPrimerShown, true);
    mockPermissions(granted: true);
    bool? granted;
    await tester.pumpWidget(
      host((ctx) async => granted = await CamMicPrimer.ensure(ctx)),
    );

    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsNothing);
    expect(granted, true);
  });

  testWidgets('denial surfaces the Settings hint and returns false', (
    tester,
  ) async {
    await appData.write(kKeyCamMicPrimerShown, true); // isolate the denial path
    mockPermissions(granted: false);
    bool? granted;
    await tester.pumpWidget(
      host((ctx) async => granted = await CamMicPrimer.ensure(ctx)),
    );

    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();

    expect(granted, false);
    expect(find.text(CamMicPrimer.deniedMessage), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  group('opening sealed media', () {
    setUp(() => CamMicPrimer.onPhone = true);
    tearDown(() => CamMicPrimer.onPhone = false);

    /// Taps through to [CamMicPrimer.allowsOpening] as a primed user.
    Future<bool?> allowsOpening(WidgetTester tester) async {
      await appData.write(kKeyCamMicPrimerShown, true);
      bool? allowed;
      await tester.pumpWidget(
        host((ctx) async => allowed = await CamMicPrimer.allowsOpening(ctx)),
      );
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      return allowed;
    }

    testWidgets('is allowed with camera and microphone, without asking', (
      tester,
    ) async {
      mockPermissions(granted: true);

      expect(await allowsOpening(tester), true);
      expect(requests, 0, reason: 'already allowed: only read, never asked');
      expect(find.text(CamMicPrimer.deniedMessage), findsNothing);
    });

    testWidgets('is refused without the camera, with the way to Settings', (
      tester,
    ) async {
      mockPermissions(granted: false);

      expect(await allowsOpening(tester), false);
      expect(requests, 1, reason: 'asks again where the OS still allows it');
      expect(find.text(CamMicPrimer.deniedMessage), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('is refused without the microphone: the reaction has sound', (
      tester,
    ) async {
      mockPermissions(granted: true, microphone: false);

      expect(await allowsOpening(tester), false);
      expect(find.text(CamMicPrimer.deniedMessage), findsOneWidget);
    });

    testWidgets('is allowed when the status cannot be read (a fault)', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            permissionChannel,
            (call) async => throw PlatformException(code: 'broken'),
          );

      expect(await allowsOpening(tester), true);
    });

    testWidgets('is allowed off the phones, where nothing can answer', (
      tester,
    ) async {
      CamMicPrimer.onPhone = false;
      mockPermissions(granted: false);

      expect(await allowsOpening(tester), true);
    });

    testWidgets('a first-timer gets the explanation before the OS prompt', (
      tester,
    ) async {
      mockPermissions(granted: true);
      bool? allowed;
      await tester.pumpWidget(
        host((ctx) async => allowed = await CamMicPrimer.allowsOpening(ctx)),
      );
      await tester.tap(find.byKey(const Key('go')));
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(allowed, true);
      expect(requests, 1);
    });
  });

  test('only iOS asks for camera and microphone at launch', () {
    // Android asks just in time: a cold prompt there risks a permanent "no".
    expect(CamMicPrimer.asksAtLaunch(TargetPlatform.iOS), isTrue);
    expect(CamMicPrimer.asksAtLaunch(TargetPlatform.android), isFalse);
  });
}
