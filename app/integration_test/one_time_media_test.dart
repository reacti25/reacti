// One-time ("view once") media on a device, against the throwaway test
// server: the scripted sender sends a one-time photo, the real app opens it
// (the patent loop: the reaction is recorded silently and uploaded), the
// sender "watches" the reaction, and the whole exchange is erased from the
// server and from the app's screen.
//
// On a device with no camera (the iPhone simulator) no reaction can exist, so
// there the journey stops at the proof that the one-timer was opened; the
// erase half runs on the Android emulator and is covered for both platforms
// by test/features/chat/presentation/inbox_screen_one_time_test.dart.
//
// Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:camera/camera.dart';
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

  testWidgets('a one-time photo is opened, reacted to, then erased for both', (
    tester,
  ) async {
    final sender = await E2eUser.login(endpoints.url, userBEmail);
    final receiver = await E2eUser.login(endpoints.url, userAEmail);
    final mediaId = await sender.sendOneTimePhoto(receiver.id);

    await startLoggedIn(tester, app.main, userAEmail);

    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    // The sealed tile says it is a one-timer; ordinary media says
    // "Click to view the media".
    await pumpUntilFound(tester, find.text('Tap to view once'));
    await tester.tap(find.text('Tap to view once'));

    await waitForOpened(
      tester,
      messageId: mediaId,
      viewerId: receiver.id,
      senderSide: () => sender.conversation(receiver.id),
      viewerSide: () => receiver.conversation(sender.id),
    );

    if ((await availableCameras()).isEmpty) {
      // No camera, no reaction: nothing more can happen to this exchange.
      await letPopupsFinish(tester);
      return;
    }

    // The app shows its own reaction as a tile, never as a video.
    await pumpUntilFound(tester, find.text('One-time reaction'));
    // The reaction is recorded, so the photo is already replaced by "Opened",
    // without leaving the chat.
    await pumpUntilFound(tester, find.text('Opened'));

    // The sender watches the reaction to the end.
    final reaction = (await sender.conversation(receiver.id)).firstWhere(
      (m) =>
          m['message_type'] == 'reaction' &&
          (m['reply_to'] as Map?)?['id'] == mediaId,
    );
    expect(reaction['is_one_time'], isTrue, reason: 'the reaction inherits it');
    await sender.finishOneTime(reaction['id'] as int);

    // Gone from the server, for both people...
    await waitFor(
      () async =>
          !(await receiver.conversation(
            sender.id,
          )).any((m) => m['id'] == mediaId || m['id'] == reaction['id']),
      what: 'the one-time exchange to be erased from the server',
      tester: tester,
    );
    // ...and from the open chat, without leaving it.
    await waitFor(
      () async => find.text('One-time reaction').evaluate().isEmpty,
      what: 'the one-time bubbles to leave the screen',
      tester: tester,
    );
    await letPopupsFinish(tester);
  });
}
