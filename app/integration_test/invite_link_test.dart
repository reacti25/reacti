// An invite link opened from outside the app shows who invited you, and
// Connect makes you friends. Android only: the iPhone simulator's debug build
// has no associated domains, so iOS never hands it the link (the real iPhone
// covers that). Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/wait.dart';

/// Opens smoke-b's invite link the way another app would, then connects.
Future<void> openInviteLink(WidgetTester tester, E2eUser bravo) async {
  final code = await bravo.inviteCode();
  askHost('open https://reacti.io/i/$code');
  await pumpUntilFound(tester, find.text('Smoke invited you'));
  await tester.tap(find.text('Connect with Smoke'));
  await pumpUntilFound(tester, find.text('Connected with Smoke'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an invite link opened from outside the app connects you', (
    tester,
  ) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await openInviteLink(tester, bravo);
    await letPopupsFinish(tester);
  });
}
