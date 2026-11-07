// A gallery batch with a caption, sent in a group on a device: the sender's
// own screen must show every photo and the caption without reopening the group
// (Achia on staging 1205: only two of three, no caption, in a group, while a
// private chat was right). Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'media_send_test.dart'
    show
        PickerStandIn,
        assetFile,
        attach,
        photoAsset,
        sendBatchOnAndroid,
        sendBatchOnIphone,
        senderShowsEach;
import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a captioned batch in a group shows whole on the sender', (
    tester,
  ) async {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final groupId = await bravo.groupId(smokeGroupName);
    await bravo.sendTextToGroup(groupId, 'send us something');

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text(smokeGroupName));
    await tester.tap(find.text(smokeGroupName));

    // Three photos on Android, as on staging; the iPhone's library holds two
    // items, so two there.
    final count = android ? 3 : 2;
    const caption = 'lab group batch caption';
    if (android) {
      ImagePickerPlatform.instance = PickerStandIn([
        for (var i = 0; i < count; i++) await assetFile(photoAsset),
      ]);
    }
    await attach(tester, 'Gallery');
    await (android ? sendBatchOnAndroid : sendBatchOnIphone)(tester, caption);

    Future<List<Map<String, dynamic>>> sent() async =>
        (await bravo.groupMessages(groupId))
            .where((m) => m['sender_id'] == alpha.id && m['file'] != null)
            .toList();
    await waitFor(
      () async => (await sent()).length >= count,
      what: 'the whole batch to reach the server',
      tester: tester,
      timeout: const Duration(minutes: 3),
    );
    final server = await sent();
    expect(server.where((m) => m['text'] == caption), hasLength(1));

    // Each photo and the caption, still in the same open screen.
    await pumpUntilFound(tester, find.text(caption));
    await senderShowsEach(tester, [
      for (final m in server) '${m['file']}'.split('/').last,
    ]);
    askHost('screenshot group-batch');
    await letPopupsFinish(tester);
  });
}
