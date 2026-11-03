// Tapping a push notification on a device, against the throwaway test server:
// a 1:1 message's notification opens that chat, a group message's opens the
// group. The test server has no Firebase account, so no real push arrives;
// the test hands the app the same data a push carries, through the app's own
// tap handler (what Firebase calls on a tap). Delivery itself is checked on
// Achia's phone. Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/helpers/notification_services.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// Taps a notification carrying [data], as Firebase does on a real tap.
void tapNotification(Map<String, dynamic> data) =>
    NotificationService().handleMessage(RemoteMessage(data: data));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tapped notification opens its chat or group', (tester) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final groupId = await bravo.groupId(smokeGroupName);

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await letPopupsFinish(tester);

    await bravo.sendText(alpha.id, 'tap me open');
    final roomId = (await bravo.conversation(alpha.id)).last['room_id'];
    // The data the server puts in a 1:1 push (ChatService::send).
    tapNotification({
      'type': 'chat_1to1',
      'id': '${bravo.id}',
      'roomId': '$roomId',
      'name': 'Smoke Bravo',
    });
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(InboxScreen),
        matching: find.text('tap me open'),
      ),
    );

    await tester.binding.handlePopRoute();
    await waitFor(
      () async => find.byType(InboxScreen).evaluate().isEmpty,
      what: 'the chat to close',
      tester: tester,
    );
    await bravo.sendTextToGroup(groupId, 'group tap me');
    // The data the server puts in a group push (GroupMessageService).
    tapNotification({
      'type': 'chat_group',
      'roomId': '$groupId',
      'name': smokeGroupName,
    });
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(GroupInboxScreen),
        matching: find.text('group tap me'),
      ),
    );
    await letPopupsFinish(tester);
  });
}
