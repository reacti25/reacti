// One-time ("view once") media in a group, on a device, against the
// throwaway test server. The scripted member sends a one-time photo to a
// fresh two-person group; the real app opens it full screen (the patent loop:
// the reaction is recorded silently and uploaded to the group), it turns to
// "Opened" and the app tells the server this member is done; the sender
// watches the reaction to the end; with everyone done, the exchange is erased
// from the server and the app's open chat, leaving "1 of 1 reacted".
// Screenshots are blocked for as long as the photo is open.
//
// A fresh group, not the seeded one: other journeys on the same test server
// add members to that, and one member who never opens it would keep the
// exchange for its full day.
//
// On a device with no camera (the iPhone simulator) no reaction can exist, so
// there the journey stops at the proof that the one-timer was opened; the
// rest is covered for both platforms by
// test/features/chat/presentation/group_inbox_screen_one_time_test.dart.
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
import 'support/wait.dart';

/// Whether the app is kept out of screenshots right now, read back from the
/// native side (see one_time_media_test.dart).
Future<bool> screenshotsBlocked() async =>
    await const MethodChannel(
      'reacti/secure_screen',
    ).invokeMethod<bool>('isSecure') ??
    false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a one-time photo in a group opens once, then is erased once '
      'everyone is done', (tester) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final name = 'Once ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await bravo.createGroup(name, [alpha.id]);
    final groupId = await bravo.groupId(name);
    final mediaId = await bravo.sendOneTimePhotoToGroup(groupId);

    Future<Map<String, dynamic>?> alphaSees(int id) async {
      for (final m in await alpha.groupMessages(groupId)) {
        if (m['id'] == id) return m;
      }
      return null;
    }

    await startLoggedIn(tester, app.main, userAEmail);

    await pumpUntilFound(tester, find.text(name));
    await tester.tap(find.text(name));
    await pumpUntilFound(tester, find.text('Tap to view once'));
    await tester.tap(find.text('Tap to view once'));
    await pumpUntilFound(tester, find.byKey(const Key('one-time-countdown')));
    await waitFor(
      screenshotsBlocked,
      what: 'screenshots to be blocked while the one-timer is open',
      tester: tester,
    );
    // Opened on the server, for this member.
    await waitFor(
      () async => (await alphaSees(mediaId))?['is_blurred'] == 0,
      what: 'the one-timer to be opened on the server',
      tester: tester,
    );

    if ((await availableCameras()).isEmpty) {
      // No camera, no reaction: leaving lets go of the screenshot block.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await tester.binding.handlePopRoute();
      await waitFor(
        () async => !await screenshotsBlocked(),
        what: 'screenshots to be allowed again after leaving',
        tester: tester,
      );
      await letPopupsFinish(tester);
      return;
    }

    // The app shows its own reaction as a tile, and the photo as "Opened".
    await pumpUntilFound(tester, find.text('One-time reaction'));
    await pumpUntilFound(tester, find.text('Opened'));
    await waitFor(
      () async => !await screenshotsBlocked(),
      what: 'screenshots to be allowed again once it closed',
      tester: tester,
    );
    // The app said this member is done: no link for them any more.
    await waitFor(
      () async => (await alphaSees(mediaId))?['file'] == null,
      what: 'the one-timer to be over for this member on the server',
      tester: tester,
    );

    // The sender watches the reaction to the end.
    final reaction = (await bravo.groupMessages(groupId)).firstWhere(
      (m) =>
          m['message_type'] == 'reaction' &&
          (m['reply_to'] as Map?)?['id'] == mediaId,
    );
    expect(reaction['is_one_time'], isTrue, reason: 'the reaction inherits it');
    await bravo.markGroupViewed(reaction['id'] as int);
    await bravo.finishGroupOneTime(reaction['id'] as int);

    // Everyone is done, so it is erased on the server: the reaction is gone,
    // the photo is only a trace...
    await waitFor(
      () async {
        final media = await alphaSees(mediaId);
        return media?['one_time_erased'] == true &&
            await alphaSees(reaction['id'] as int) == null;
      },
      what: 'the group one-time exchange to be erased on the server',
      tester: tester,
    );
    // ...and in the open chat, without leaving it.
    await waitFor(
      () async => find.text('One-time reaction').evaluate().isEmpty,
      what: 'the one-time reaction to leave the screen',
      tester: tester,
    );
    await pumpUntilFound(tester, find.text('One-time photo · 1 of 1 reacted'));
    await letPopupsFinish(tester);
  });
}
