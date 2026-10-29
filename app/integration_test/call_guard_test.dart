// During a phone call a sealed photo stays sealed: nothing is marked viewed and
// nothing is recorded (the call holds the microphone). The host script starts
// a real emulator phone call (`adb emu gsm call` + `accept`) before this test
// and hangs up after it.
//
// Driven by .github/scripts/android_e2e.sh. Plan:
// docs/PLAN-device-testing-2026-10-29.md, phase 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/helpers/call_status.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a sealed photo stays sealed during a phone call', (
    tester,
  ) async {
    final sender = await E2eUser.login(endpoints.url, userBEmail);
    final receiver = await E2eUser.login(endpoints.url, userAEmail);
    final sealedId = await sender.sendSealedPhoto(receiver.id);

    await startLoggedIn(tester, app.main, userAEmail);
    await waitFor(
      callStatus.isInCall,
      what: 'the host to put the emulator on a call',
      tester: tester,
    );
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, find.text('Click to view the media'));
    await tester.tap(find.text('Click to view the media'));

    await pumpUntilFound(tester, find.text(kInCallOpenMessage));
    final messages = await sender.conversation(receiver.id);
    final sealed = messages.firstWhere((m) => m['id'] == sealedId);
    expect(sealed['is_viewed'], 0, reason: 'nothing may be marked viewed');
    expect(
      hasReactionTo(messages, messageId: sealedId, senderId: receiver.id),
      isFalse,
      reason: 'nothing may be recorded',
    );
    expect(find.text('Click to view the media'), findsOneWidget);
    // Let the toast finish before the test ends.
    await tester.pump(const Duration(seconds: 5));
  });
}
