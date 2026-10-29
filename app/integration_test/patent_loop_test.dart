// The patent loop on a device, against the throwaway test server: the scripted
// sender seals a photo, the real app logs in as the receiver, opens it, records
// the reaction silently with the device's front camera, and the sender gets it.
//
// Driven by .github/scripts/android_e2e.sh (boots nothing itself: the server
// comes from e2e_backend.sh, permissions are granted from the host). Plan:
// docs/PLAN-device-testing-2026-10-29.md, phase 2.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/e2e_api.dart';
import 'support/wait.dart';

/// Marks the first-run screens and coach marks as seen, so the test goes from
/// login straight to the chats. Each has its own unit tests; here they would
/// only catch the taps.
Future<void> skipFirstRunScreens() async {
  await GetStorage.init();
  final storage = GetStorage();
  for (final key in [
    kKeyDemoSeen,
    kKeyTourSeen,
    kKeyTourFirstChatSeen,
    kKeyTourAttachSeen,
    kKeyTourSealedSeen,
    kKeyTourSentMediaSeen,
    kKeyCamMicPrimerShown,
  ]) {
    await storage.write(key, true);
  }
  await storage.write(kKeyIsFirstTime, false);
}

/// Logs into the app's login screen as [email].
Future<void> logIn(WidgetTester tester, String email) async {
  await pumpUntilFound(tester, find.text('Sign In'));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), e2ePassword);
  await tester.tap(find.text('Sign In'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opening a sealed photo records a reaction the sender receives', (
    tester,
  ) async {
    final sender = await E2eUser.login(endpoints.url, userBEmail);
    final receiver = await E2eUser.login(endpoints.url, userAEmail);
    final sealedId = await sender.sendSealedPhoto(receiver.id);

    await skipFirstRunScreens();
    app.main();
    await logIn(tester, userAEmail);

    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, find.text('Click to view the media'));
    await tester.tap(find.text('Click to view the media'));

    // The recording runs for a few seconds, then uploads; the sender's side
    // of the server is the proof, not the receiver's screen.
    await waitFor(
      () async => hasReactionTo(
        await sender.conversation(receiver.id),
        messageId: sealedId,
        senderId: receiver.id,
      ),
      what: 'the reaction to reach the sender',
      tester: tester,
    );
  });
}
