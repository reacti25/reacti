// Undoing things on a device, against the throwaway test server: unfriend
// and friend again, block and unblock, delete a chat, and leave a group, each
// checked on the server. smoke-f plays the friend; smoke-b owns the group.
// Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

const foxtrotName = 'Smoke Foxtrot';
const groupName = 'Leave Me Group';

/// The [icon] on the same row as [text]: the nearest one vertically, since
/// list rows carry no keys.
Finder iconOnRowOf(WidgetTester tester, String text, IconData icon) {
  final y = tester.getCenter(find.text(text).last).dy;
  final icons = find.byIcon(icon);
  var best = 0;
  for (var i = 1; i < icons.evaluate().length; i++) {
    if ((tester.getCenter(icons.at(i)).dy - y).abs() <
        (tester.getCenter(icons.at(best)).dy - y).abs()) {
      best = i;
    }
  }
  return icons.at(best);
}

/// Taps [label] once its menu or dialog has finished growing in.
Future<void> tapWhenShown(WidgetTester tester, String label) async {
  await pumpUntilFound(tester, find.text(label));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(label).last);
}

/// Friends tab: unfriends smoke-f, then sends a new request by username.
Future<void> unfriendAndBack(
  WidgetTester tester,
  E2eUser foxtrot,
  E2eUser alpha,
) async {
  await tester.tap(find.text('Friends').last);
  await pumpUntilFound(tester, find.text(foxtrotName));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(iconOnRowOf(tester, foxtrotName, Icons.more_vert));
  await tapWhenShown(tester, 'Unfriend'); // the menu item
  await tapWhenShown(tester, 'Unfriend'); // the dialog's button
  await waitFor(
    () async => !(await foxtrot.fetch('/friends/list')).contains('Alpha'),
    what: 'smoke-f to no longer have alpha as a friend',
    tester: tester,
  );
  await letPopupsFinish(tester);

  await tester.tap(find.byTooltip('Find people on Reacti'));
  await pumpUntilFound(
    tester,
    find.text('Search for someone by their username'),
  );
  await tester.tap(find.byIcon(Icons.search).last);
  await pumpUntilFound(tester, find.byType(TextFormField));
  await tester.enterText(find.byType(TextFormField).last, 'smoke_f');
  await tapWhenShown(tester, 'Send Request');
  await waitFor(
    () async => (await foxtrot.fetch('/friends/requests')).contains('Alpha'),
    what: "alpha's new request to reach smoke-f",
    tester: tester,
  );
  await foxtrot.acceptFriendRequest(alpha.id);
  await tester.binding.handlePopRoute();
  await letPopupsFinish(tester);
}

/// smoke-f's chat: blocks, then unblocks from the chat.
Future<void> blockAndUnblock(WidgetTester tester, E2eUser alpha) async {
  Future<bool> blocked() async =>
      (await alpha.fetch('/block/list')).contains('Foxtrot');

  await tester.tap(find.text('Chat').last);
  await pumpUntilFound(tester, find.text(foxtrotName));
  await tester.tap(find.text(foxtrotName));
  await pumpUntilFound(tester, find.byType(InboxScreen));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(
    find.descendant(
      of: find.byType(InboxScreen),
      matching: find.byIcon(Icons.more_vert),
    ),
  );
  await tapWhenShown(tester, 'Block This User');
  await waitFor(blocked, what: 'smoke-f to be blocked', tester: tester);
  await tapWhenShown(tester, 'Unblock');
  await waitFor(
    () async => !await blocked(),
    what: 'smoke-f to be unblocked',
    tester: tester,
  );
  await tester.binding.handlePopRoute();
  await waitFor(
    () async => find.byType(InboxScreen).evaluate().isEmpty,
    what: 'the chat to close',
    tester: tester,
  );
}

/// Chat list: long-press smoke-f's chat and delete it.
Future<void> deleteChat(WidgetTester tester, E2eUser alpha) async {
  await letPopupsFinish(tester);
  await pumpUntilFound(tester, find.text(foxtrotName));
  await tester.longPress(find.text(foxtrotName));
  await tapWhenShown(tester, 'Delete');
  await waitFor(
    () async => !(await alpha.fetch('/auth/chat/list')).contains('Foxtrot'),
    what: "smoke-f's chat to be deleted",
    tester: tester,
  );
}

/// Opens smoke-b's group, its details, and leaves it.
Future<void> leaveGroup(WidgetTester tester, E2eUser alpha) async {
  await pumpUntilFound(tester, find.text(groupName));
  await tester.tap(find.text(groupName));
  await pumpUntilFound(tester, find.byType(GroupInboxScreen));
  await tester.pump(const Duration(seconds: 1));
  // The group's name in the top bar opens its details.
  await tester.tap(
    find.descendant(
      of: find.byType(GroupInboxScreen),
      matching: find.text(groupName),
    ),
  );
  await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.byIcon(Icons.more_vert).last);
  await tapWhenShown(tester, 'Leave Group');
  await tapWhenShown(tester, 'Leave');
  await waitFor(
    () async => !(await alpha.fetch('/auth/group/list')).contains(groupName),
    what: 'alpha to have left the group',
    tester: tester,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unfriend, block, delete a chat and leave a group', (
    tester,
  ) async {
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final foxtrot = await E2eUser.login(endpoints.url, userFEmail);
    await foxtrot.sendFriendRequest(alpha.id);
    await alpha.acceptFriendRequest(foxtrot.id);
    await foxtrot.sendText(alpha.id, 'hi from foxtrot');
    await bravo.createGroup(groupName, [alpha.id]);
    await bravo.sendTextToGroup(await bravo.groupId(groupName), 'welcome');

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await letPopupsFinish(tester);

    await unfriendAndBack(tester, foxtrot, alpha);
    await blockAndUnblock(tester, alpha);
    await deleteChat(tester, alpha);
    await leaveGroup(tester, alpha);
    await letPopupsFinish(tester);
  });
}
