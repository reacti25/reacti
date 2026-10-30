// Chatting on a device, against the throwaway test server: messages arrive
// live (websocket), a typed message reaches the other person, and the patent
// loop works in a group too. The scripted smoke-b plays everyone else.
//
// Driven by the testing lab (.github/workflows/testing-lab.yml). Plan:
// docs/PLAN-device-testing-2026-10-29.md, phase 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/chat.dart';
import 'support/e2e_api.dart';
import 'support/opened.dart';
import 'support/wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live messages, sending, and a sealed photo in a group', (
    tester,
  ) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final groupId = await bravo.groupId(smokeGroupName);
    // The chat row exists only once the two have talked.
    await bravo.sendText(alpha.id, 'hi from bravo');

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, inChat('hi from bravo'));

    // Arrives while the chat is open: only the websocket can bring it.
    await bravo.sendText(alpha.id, 'live from bravo');
    await pumpUntilFound(tester, inChat('live from bravo'));

    await sendInChat(tester, 'hello from alpha');
    await waitFor(
      () async => (await bravo.conversation(
        alpha.id,
      )).any((m) => m['text'] == 'hello from alpha'),
      what: 'the typed message to reach smoke-b',
      tester: tester,
    );

    // Back to the chat list, then the group's sealed photo.
    final sealedId = await bravo.sendSealedPhotoToGroup(groupId);
    await tester.binding.handlePopRoute();
    await pumpUntilFound(tester, find.text(smokeGroupName));
    await tester.tap(find.text(smokeGroupName));
    await pumpUntilFound(tester, find.text('Click to view the media'));
    await tester.tap(find.text('Click to view the media'));
    await waitForOpened(
      tester,
      messageId: sealedId,
      viewerId: alpha.id,
      senderSide: () => bravo.groupMessages(groupId),
      viewerSide: () => alpha.groupMessages(groupId),
    );
    await letPopupsFinish(tester);
  });
}
