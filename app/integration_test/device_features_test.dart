// Phone features on a device, against the throwaway test server: an invite
// link opened from outside the app, sending while the server is unreachable,
// and App Lock with the phone's real unlock screen (a PIN, typed by the host).
//
// Driven by .github/scripts/android_e2e.sh; the host acts on the emulator
// through support/host.dart. Plan: docs/PLAN-device-testing-2026-10-29.md,
// phase 2b.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/wait.dart';

/// The emulator's screen-lock PIN, set by the host for the App Lock step.
const pin = '1111';

/// Opens smoke-b's invite link the way another app would, then connects.
Future<void> openInviteLink(WidgetTester tester, E2eUser bravo) async {
  final code = await bravo.inviteCode();
  askHost(
    'shell am start -a android.intent.action.VIEW '
    '-d https://reacti.io/i/$code com.reacti.app',
  );
  await pumpUntilFound(tester, find.text('Smoke invited you'));
  await tester.tap(find.text('Connect with Smoke'));
  await pumpUntilFound(tester, find.text('Connected with Smoke'));
}

/// Sends a message with the server unreachable, then again once it is back.
Future<void> sendWhileOffline(
  WidgetTester tester,
  E2eUser alpha,
  E2eUser bravo,
) async {
  await bravo.sendText(alpha.id, 'are you there?');
  await pumpUntilFound(tester, find.text('Smoke Bravo'));
  await tester.tap(find.text('Smoke Bravo'));
  final composer = find.descendant(
    of: find.byType(InboxScreen),
    matching: find.byType(TextFormField),
  );
  await pumpUntilFound(tester, composer);

  Future<bool> bravoHas(String text) async =>
      (await bravo.conversation(alpha.id)).any((m) => m['text'] == text);

  // To the app, a server it cannot reach looks exactly like no internet.
  askHost('reverse --remove tcp:8000');
  await tester.enterText(composer, 'sent offline');
  await tester.tap(find.byKey(const Key('composer_send_button')));
  await pumpUntilFound(tester, find.text('An error occurred'));
  askHost('reverse tcp:8000 tcp:8000');
  await letPopupsFinish(tester);
  expect(await bravoHas('sent offline'), isFalse);

  await tester.enterText(composer, 'sent back online');
  await tester.tap(find.byKey(const Key('composer_send_button')));
  await waitFor(
    () => bravoHas('sent back online'),
    what: 'the message sent after reconnecting to reach smoke-b',
    tester: tester,
  );
}

/// Leaves the app with App Lock on, comes back, and unlocks with the PIN.
Future<void> lockAndUnlock(WidgetTester tester) async {
  askHost('shell locksettings set-pin $pin');
  final storage = GetStorage();
  await storage.write(kKeyAppLockEnabled, true);
  await storage.write(kKeyAppLockDelay, 'immediately');

  askHost('shell input keyevent KEYCODE_HOME');
  // No frames while backgrounded: wait in plain time, not with pump.
  await Future<void>.delayed(const Duration(seconds: 3));
  askHost(
    'shell monkey -p com.reacti.app -c android.intent.category.LAUNCHER 1',
  );
  await pumpUntilFound(tester, find.text('Reacti is locked'));

  await tester.tap(find.text('Unlock'));
  // The phone's own unlock screen: Flutter cannot see it, the host types.
  await Future<void>.delayed(const Duration(seconds: 3));
  askHost('shell input text $pin');
  askHost('shell input keyevent KEYCODE_ENTER');
  await waitFor(
    () async => find.text('Reacti is locked').evaluate().isEmpty,
    what: 'the PIN to unlock the app',
    tester: tester,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invite link, sending offline, and App Lock', (tester) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await openInviteLink(tester, bravo);
    await letPopupsFinish(tester);
    await sendWhileOffline(tester, alpha, bravo);
    await lockAndUnlock(tester);
    await letPopupsFinish(tester);
  });
}
