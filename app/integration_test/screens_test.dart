// Every screen once, on a device, against the throwaway test server: opens
// each, saves a picture of it with the lab's logs (lab-shots/screens-NAME.png),
// and goes back. A screen that throws or overflows fails the journey; the
// pictures show what each phone really drew. Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/wait.dart';

/// Lets the screen settle, then saves its picture as [name].
Future<void> shoot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(seconds: 2));
  askHost('screenshot $name');
  await tester.pump(const Duration(seconds: 2)); // the host takes it
}

/// Goes back one screen (or closes the sheet or dialog on top).
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(seconds: 1));
}

/// Taps [target] (scrolled into view), pictures what opens as [name], backs out.
Future<void> visit(WidgetTester tester, Finder target, String name) async {
  await pumpUntilFound(tester, target);
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(target);
  await shoot(tester, name);
  await back(tester);
}

/// Chat tab: the list, a 1:1 chat with its menu and report screen, a group
/// with its details, and New group.
Future<void> chatScreens(WidgetTester tester) async {
  await shoot(tester, 'chat-list');
  await tester.tap(find.text('Smoke Bravo'));
  await pumpUntilFound(tester, find.byType(InboxScreen));
  await shoot(tester, 'chat');
  await tester.tap(
    find.descendant(
      of: find.byType(InboxScreen),
      matching: find.byIcon(Icons.more_vert),
    ),
  );
  await pumpUntilFound(tester, find.text('Report This User'));
  await tester.pump(const Duration(seconds: 1));
  await visit(tester, find.text('Report This User'), 'report-user');
  await back(tester); // the chat
  // The iPhone's slide-back is slow: a tap while it runs misses the row.
  await waitFor(
    () async => find.byType(InboxScreen).evaluate().isEmpty,
    what: 'the chat to close',
    tester: tester,
  );

  await pumpUntilFound(tester, find.text(smokeGroupName));
  await tester.tap(find.text(smokeGroupName));
  await pumpUntilFound(tester, find.byType(GroupInboxScreen));
  await shoot(tester, 'group');
  await visit(
    tester,
    find.descendant(
      of: find.byType(GroupInboxScreen),
      matching: find.text(smokeGroupName),
    ),
    'group-details',
  );
  await back(tester); // the group
  await waitFor(
    () async => find.byType(GroupInboxScreen).evaluate().isEmpty,
    what: 'the group to close',
    tester: tester,
  );
  await visit(tester, find.bySemanticsLabel('New group'), 'new-group');
}

/// Friends, Contacts, Find people and Requests.
Future<void> friendScreens(WidgetTester tester) async {
  // New group lists "Friends" too and is still closing on a slow phone.
  await waitFor(
    () async => find.text('Create Group').evaluate().isEmpty,
    what: 'New group to close',
    tester: tester,
  );
  await tester.tap(find.text('Friends').last);
  await shoot(tester, 'friends');
  await tester.tap(find.text('Contacts').last);
  await shoot(tester, 'contacts');
  await visit(tester, find.byTooltip('Find people on Reacti'), 'find-people');
  await tester.tap(find.text('Requests').last);
  await shoot(tester, 'requests');
}

/// Profile and everything under it, Settings included.
Future<void> profileScreens(WidgetTester tester) async {
  await tester.tap(find.text('Profile').last);
  await shoot(tester, 'profile');
  for (final (row, name) in [
    ('Edit Profile', 'edit-profile'),
    ('App Lock', 'app-lock'),
    ('Connect with an inviter', 'invite-code'),
  ]) {
    await visit(tester, find.text(row), name);
  }
  await tester.ensureVisible(find.text('Settings'));
  await tester.tap(find.text('Settings'));
  await shoot(tester, 'settings');
  for (final (row, name) in [
    ('Change Password', 'change-password'),
    ('Read Receipts', 'read-receipts'),
    ('Blocked Users', 'blocked-users'),
    ('Permissions', 'permissions'),
    ('Appearance', 'appearance'),
    ('Sound & Vibration', 'sound'),
    ('Usage Data', 'usage-data'),
    ('Privacy Policy', 'privacy-policy'),
  ]) {
    // Change Password is also the title of its own screen: tap the row.
    await visit(tester, find.text(row).first, name);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every screen opens and draws', (tester) async {
    // A chat with smoke-b to open, whatever ran before on this server.
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    await bravo.sendText(alpha.id, 'a chat to look at');
    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await letPopupsFinish(tester);

    await chatScreens(tester);
    await friendScreens(tester);
    await profileScreens(tester);
  });
}
