// Groups on a device, against the throwaway test server: create a group with
// a friend in it, the friend's message shows up live in it, and a text sent
// to it can be edited right away. Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/widget/message_edit_bar.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/chat.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// The group this journey creates.
const labGroup = 'Lab Group';

/// Chat tab "+": names the group, picks smoke-b, and creates it.
Future<void> createGroup(WidgetTester tester, E2eUser bravo) async {
  final plus = find.byWidgetPredicate(
    (w) => w is Icon && w.semanticLabel == 'New group',
  );
  await pumpUntilFound(tester, plus);
  await tester.tap(plus);
  await pumpUntilFound(tester, find.text('Create Group'));
  await tester.enterText(find.byType(TextFormField).first, labGroup);
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpUntilFound(tester, find.text('Smoke Bravo'));
  await tester.tap(find.text('Smoke Bravo'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byIcon(Icons.done));
  await waitFor(
    () async => (await bravo.fetch('/auth/group/list')).contains(labGroup),
    what: 'smoke-b to be in the new group',
    tester: tester,
  );
}

/// In the open group: sends a text and edits it straight away; smoke-b gets
/// the edited text.
///
/// The server sends a group message to the other members only, so nothing
/// ever replaces the sender's own copy of it. That copy once had no send time,
/// and Edit stayed hidden until the group was reopened (Achia, staging 1209).
Future<void> editJustSentText(WidgetTester tester, E2eUser bravo) async {
  final groupId = await bravo.groupId(labGroup);
  Future<bool> bravoSees(String text) async =>
      (await bravo.groupMessages(groupId)).any((m) => m['text'] == text);

  await sendInChat(tester, 'tpyo in the group');
  // Edit is offered once the send is confirmed, not while it is in flight.
  await waitFor(
    () => bravoSees('tpyo in the group'),
    what: 'the group text to reach the server',
    tester: tester,
  );
  await pickAction(tester, 'tpyo in the group', 'Edit');
  await tester.enterText(
    find.descendant(
      of: find.byType(MessageEditBar),
      matching: find.byType(TextField),
    ),
    'group typo fixed',
  );
  await tester.tap(find.byIcon(Icons.check_circle));
  await waitFor(
    () => bravoSees('group typo fixed'),
    what: 'the edited group text to reach smoke-b',
    tester: tester,
  );
  await letPopupsFinish(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create a group and get a message in it', (tester) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    // The login toast covers the top bar, where "+" is.
    await letPopupsFinish(tester);
    await createGroup(tester, bravo);

    await bravo.sendTextToGroup(await bravo.groupId(labGroup), 'hi lab group');
    await pumpUntilFound(tester, find.text(labGroup));
    // The "created" toast covers the top row for a few seconds.
    await letPopupsFinish(tester);
    await tester.tap(find.text(labGroup).first);
    // In the open group, not the chat list's preview.
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(GroupInboxScreen),
        matching: find.text('hi lab group'),
      ),
    );
    await letPopupsFinish(tester);
    await editJustSentText(tester, bravo);
  });
}
