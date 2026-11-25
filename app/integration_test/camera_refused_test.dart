// No camera, no viewing, on a device against the throwaway test server: with
// camera access refused, tapping sealed media keeps it sealed, the box in the
// middle of the screen says why, "Not now" closes it, and the server never
// hears the media was viewed.
//
// The lab refuses the camera for this journey only, before the app starts
// (a system prompt cannot be tapped from Dart): see camera_refused in
// .github/scripts/android_e2e.sh and ios_e2e.sh. Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('without the camera, media stays sealed and the box says why', (
    tester,
  ) async {
    final sender = await E2eUser.login(endpoints.url, userBEmail);
    final receiver = await E2eUser.login(endpoints.url, userAEmail);
    // One-time only so its tile is the one "Tap to view once" in the chat;
    // the rule is the same for every sealed media.
    final mediaId = await sender.sendOneTimePhoto(receiver.id);

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, find.text('Tap to view once'));
    await tester.tap(find.text('Tap to view once'));

    final box = find.byKey(const Key('cam-mic-denied'));
    await pumpUntilFound(tester, box);
    expect(find.text('Open Settings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cam-mic-not-now')));
    await waitFor(
      () async => box.evaluate().isEmpty,
      what: 'the box to close',
      tester: tester,
    );
    // Still sealed on screen...
    expect(find.text('Tap to view once'), findsOneWidget);
    // ...and on the server: nothing was marked viewed, so it opens normally
    // once access is given.
    final media = (await receiver.conversation(
      sender.id,
    )).firstWhere((m) => m['id'] == mediaId);
    expect(media['is_viewed'] == true || media['is_viewed'] == 1, isFalse);
    await letPopupsFinish(tester);
  });
}
