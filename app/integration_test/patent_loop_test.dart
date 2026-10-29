// The patent loop on a device, against the throwaway test server: the scripted
// sender seals a photo, the real app logs in as the receiver, opens it, records
// the reaction silently with the device's front camera, and the sender gets it.
//
// Driven by the testing lab (.github/workflows/testing-lab.yml): the server
// comes from e2e_backend.sh, permissions are granted from the host. Plan:
// docs/PLAN-device-testing-2026-10-29.md, phase 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/opened.dart';
import 'support/wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opening a sealed photo records a reaction the sender receives', (
    tester,
  ) async {
    final sender = await E2eUser.login(endpoints.url, userBEmail);
    final receiver = await E2eUser.login(endpoints.url, userAEmail);
    final sealedId = await sender.sendSealedPhoto(receiver.id);

    await startLoggedIn(tester, app.main, userAEmail);

    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, find.text('Click to view the media'));
    await tester.tap(find.text('Click to view the media'));

    // The recording runs for a few seconds, then uploads; the server is the
    // proof, not the receiver's screen.
    await waitForOpened(
      tester,
      messageId: sealedId,
      viewerId: receiver.id,
      senderSide: () => sender.conversation(receiver.id),
      viewerSide: () => receiver.conversation(sender.id),
    );
    await letPopupsFinish(tester);
  });
}
