// A first run on a device, against the throwaway test server: the practice
// ("demo") Reacti, the "How a Reacti works" card, and the first coach mark on
// the chat list, then the walkthrough is remembered as seen. Driven by the
// testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/lifecycle.dart';
import 'support/wait.dart';

/// Taps [label] once it has finished animating in.
Future<void> tapWhenShown(WidgetTester tester, String label) async {
  await pumpUntilFound(tester, find.text(label));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(label).last);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo Reacti, the walkthrough card and the first tip', (
    tester,
  ) async {
    // A chat, so the tip has a first row to point at.
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    await bravo.sendText(alpha.id, 'welcome aboard');
    await skipFirstRunScreens();
    // Back to a first-timer for the demo, the tour and the chat-list tip.
    // (The camera explanation stays seen: it has its own tests.)
    final storage = GetStorage();
    for (final key in [kKeyDemoSeen, kKeyTourSeen, kKeyTourFirstChatSeen]) {
      await storage.remove(key);
    }
    logLifecycle();
    app.main();
    await logIn(tester, userAEmail);

    // The practice Reacti: open it, it records (Android) and reveals.
    // Pictures at each step: the iPhone once left the app here unexplained.
    await tapWhenShown(tester, 'Open demo Reacti');
    askHost('screenshot demo-opened');
    await tapWhenShown(tester, 'Send your first Reacti');
    askHost('screenshot demo-done');

    await pumpUntilFound(tester, find.text('How a Reacti works'));
    await tapWhenShown(tester, 'Send my first Reacti');

    // Alpha has chats, so the tip lands on the chat list's first row.
    await pumpUntilFound(tester, find.text('Pick someone'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(20, 20)); // a tap anywhere moves on
    await waitFor(
      () async => find.text('Pick someone').evaluate().isEmpty,
      what: 'the tip to close',
      tester: tester,
    );
    expect(storage.read(kKeyTourSeen), isTrue);
    expect(storage.read(kKeyDemoSeen), isTrue);
    await letPopupsFinish(tester);
  });
}
