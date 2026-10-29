// During a phone call a sealed photo stays sealed: nothing is marked viewed and
// nothing is recorded (the call holds the microphone). The test has the host
// place a real emulator phone call and answer it, then hang up.
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
import 'support/host.dart';
import 'support/wait.dart';

/// The emulator's simulated caller.
const phone = '5551234';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a sealed photo stays sealed during a phone call', (
    tester,
  ) async {
    final sender = await E2eUser.login(endpoints.url, userBEmail);
    final receiver = await E2eUser.login(endpoints.url, userAEmail);
    final sealedId = await sender.sendSealedPhoto(receiver.id);

    await startLoggedIn(tester, app.main, userAEmail);
    // An answered call puts Android's audio in call mode, which the app checks.
    askHost('emu gsm call $phone');
    await tester.pump(const Duration(seconds: 2));
    askHost('emu gsm accept $phone');
    addTearDown(() => askHost('emu gsm cancel $phone'));
    await waitFor(
      callStatus.isInCall,
      what: 'the emulator to be on a call',
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
    await letPopupsFinish(tester);
  });
}
