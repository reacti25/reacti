// A screenshot of one-time media, told to its sender, on a device against
// the throwaway test server: the app's user sends a one-time photo, the
// scripted peer's iPhone reports a screenshot of it, and the sender's open
// chat turns the tile to "Screenshot attempt" live.
//
// The report itself comes from the iPhone's own screenshot notice, which a
// simulator cannot raise from a script; it is covered by
// test/helpers/secure_screen_test.dart and was checked on a real iPhone
// (staging 1219). Android blocks the screenshot instead: see the check in
// one_time_media_test.dart. Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("the sender's tile says when the peer took a screenshot", (
    tester,
  ) async {
    final me = await E2eUser.login(endpoints.url, userAEmail);
    final peer = await E2eUser.login(endpoints.url, userBEmail);
    final mediaId = await me.sendOneTimePhoto(peer.id);

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await letPopupsFinish(tester);
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, find.text('One-time photo'));
    // The chat's live connection needs a moment after the screen opens.
    await tester.pump(const Duration(seconds: 2));

    await peer.reportOneTimeScreenshot(mediaId);

    await pumpUntilFound(tester, find.text('Screenshot attempt'));
    expect(find.text('One-time photo'), findsNothing);
    await letPopupsFinish(tester);
  });
}
