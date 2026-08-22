// Widget tests for the Feature 8c just-in-time camera/mic primer.
//
// Pins: the one-time explanation dialog shows once and sets
// kKeyCamMicPrimerShown; a primed user skips straight to the permission
// request; a denial surfaces the gentle "enable in Settings" hint and returns
// false (never hard-blocks). The permission_handler channel is mocked so
// `.request()` resolves without a real platform.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/cam_mic_primer.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/test_storage.dart';

void main() {
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  /// Mocks the permission channel to grant or deny whatever is requested.
  void mockPermissions({required bool granted}) {
    // PermissionStatus: 0 = denied, 1 = granted.
    final status = granted ? 1 : 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'requestPermissions') {
            final requested = (call.arguments as List).cast<int>();
            return {for (final p in requested) p: status};
          }
          if (call.method == 'checkPermissionStatus') return status;
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
    expect(find.textContaining('Enable camera & microphone'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
