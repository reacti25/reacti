// One-time ("view once") media on a device, against the throwaway test
// server: the scripted sender sends a one-time photo, the real app opens it
// full screen (the patent loop: the reaction is recorded silently and
// uploaded), it turns to "Opened", the sender "watches" the reaction, and
// the exchange is erased from the server and the app's screen, leaving
// only a one-line trace of the photo.
// Screenshots are blocked for as long as the photo is open, on both phones.
//
// On a device with no camera (the iPhone simulator) no reaction can exist, so
// there the journey stops at the proof that the one-timer was opened; the
// erase half runs on the Android emulator and is covered for both platforms
// by test/features/chat/presentation/inbox_screen_one_time_test.dart.
//
// Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/opened.dart';
import 'support/wait.dart';

/// Whether the app is kept out of screenshots right now, read back from the
/// native side (Android's FLAG_SECURE in MainActivity.kt, the iPhone's
/// password-field layer in AppDelegate.swift).
Future<bool> screenshotsBlocked() async =>
    await const MethodChannel(
      'reacti/secure_screen',
    ).invokeMethod<bool>('isSecure') ??
    false;

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
    // The photo opens full screen by itself, with the countdown to its closing.
    await pumpUntilFound(tester, find.byKey(const Key('one-time-countdown')));
    await waitFor(
      screenshotsBlocked,
      what: 'screenshots to be blocked while the one-timer is open',
      tester: tester,
    );

    await waitForOpened(
      tester,
      messageId: mediaId,
      viewerId: receiver.id,
      senderSide: () => sender.conversation(receiver.id),
      viewerSide: () => receiver.conversation(sender.id),
    );

    if ((await availableCameras()).isEmpty) {
      // No camera, no reaction: nothing more can happen to this exchange.
      // Leaving the photo and the chat lets go of the screenshot block, and
      // the app is drawn the ordinary way again.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await tester.binding.handlePopRoute();
      await waitFor(
        () async => !await screenshotsBlocked(),
        what: 'screenshots to be allowed again after leaving',
        tester: tester,
      );
      await pumpUntilFound(tester, find.text('Smoke Bravo'));
      await letPopupsFinish(tester);
      return;
    }

    // The app shows its own reaction as a tile, never as a video.
    await pumpUntilFound(tester, find.text('One-time reaction'));
    // The reaction is recorded, so the photo is already replaced by "Opened",
    // without leaving the chat, and screenshots are allowed again.
    await pumpUntilFound(tester, find.text('Opened'));
    await waitFor(
      () async => !await screenshotsBlocked(),
      what: 'screenshots to be allowed again once it closed',
      tester: tester,
    );

    // The sender watches the reaction to the end.
    final reaction = (await sender.conversation(receiver.id)).firstWhere(
      (m) =>
          m['message_type'] == 'reaction' &&
          (m['reply_to'] as Map?)?['id'] == mediaId,
    );
    expect(reaction['is_one_time'], isTrue, reason: 'the reaction inherits it');
    await sender.finishOneTime(reaction['id'] as int);

    // Erased on the server: the reaction is gone, the photo is only a trace...
    await waitFor(
      () async {
        final rows = await receiver.conversation(sender.id);
        return !rows.any((m) => m['id'] == reaction['id']) &&
            rows.any((m) => m['id'] == mediaId && m['one_time_erased'] == true);
      },
      what: 'the one-time exchange to be erased on the server',
      tester: tester,
    );
    // ...and in the open chat, without leaving it.
    await waitFor(
      () async => find.text('One-time reaction').evaluate().isEmpty,
      what: 'the one-time reaction to leave the screen',
      tester: tester,
    );
    await pumpUntilFound(tester, find.text('One-time photo · reacted'));
    await letPopupsFinish(tester);
  });
}
