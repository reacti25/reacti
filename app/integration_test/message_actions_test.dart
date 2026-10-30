// The long-press message menu on a device, against the throwaway test server:
// reply, edit, forward to the group, and delete for everyone, each checked on
// the other person's side of the server. Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/forward_picker_screen.dart';
import 'package:reacti_app/features/chat/presentation/widget/message_edit_bar.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/chat.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// Long-presses the message showing [text] and picks [action] from the menu.
Future<void> pickAction(WidgetTester tester, String text, String action) async {
  await pumpUntilFound(tester, inChat(text));
  // Let the list settle (the keyboard or edit bar closing moves it), or the
  // long press is cancelled mid-way.
  await tester.pump(const Duration(seconds: 1));
  await tester.longPress(inChat(text));
  try {
    await pumpUntilFound(
      tester,
      find.text(action),
      timeout: const Duration(seconds: 5),
    );
  } on TestFailure {
    // ponytail: the lab's simulated touch loses a second long-press on the
    // same message (Achia checked the real phone: it opens, 2026-10-30), so
    // fall back to the bubble's own long-press handler, the code a real press
    // runs. The first press on each message is always a real gesture.
    debugPrint('long-press swallowed on "$text"; calling its handler');
    tester
        .widgetList<GestureDetector>(
          find.ancestor(
            of: inChat(text),
            matching: find.byType(GestureDetector),
          ),
        )
        .firstWhere((g) => g.onLongPressStart != null)
        .onLongPressStart!(
      LongPressStartDetails(globalPosition: tester.getCenter(inChat(text))),
    );
    await pumpUntilFound(tester, find.text(action));
  }
  // The menu grows in: a tap during the animation misses the row.
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(action));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reply, edit, forward and delete a message', (tester) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final groupId = await bravo.groupId(smokeGroupName);
    Future<List<Map<String, dynamic>>> bravoSees() =>
        bravo.conversation(alpha.id);

    await bravo.sendText(alpha.id, 'please reply');
    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));

    await pickAction(tester, 'please reply', 'Reply');
    await sendInChat(tester, 'this is a reply');
    final original = (await bravoSees()).firstWhere(
      (m) => m['text'] == 'please reply',
    );
    await waitFor(
      () async => (await bravoSees()).any(
        (m) =>
            m['text'] == 'this is a reply' &&
            (m['reply_to'] as Map?)?['id'] == original['id'],
      ),
      what: 'the reply, quoting the message, to reach smoke-b',
      tester: tester,
    );

    await pickAction(tester, 'this is a reply', 'Forward');
    final group = find.descendant(
      of: find.byType(ForwardPickerScreen),
      matching: find.text(smokeGroupName),
    );
    await pumpUntilFound(tester, group);
    await tester.tap(group);
    await pumpUntilFound(tester, find.text('Send (1)'));
    await tester.tap(find.text('Send (1)'));
    await waitFor(
      () async => (await bravo.groupMessages(groupId)).any(
        (m) => m['text'] == 'this is a reply' && m['sender_id'] == alpha.id,
      ),
      what: 'the forwarded message to reach the group',
      tester: tester,
    );

    await pickAction(tester, 'this is a reply', 'Delete');
    await tester.tap(find.text('Delete for everyone'));
    await waitFor(
      () async =>
          !(await bravoSees()).any((m) => m['text'] == 'this is a reply'),
      what: 'the message to be deleted for smoke-b too',
      tester: tester,
    );

    await sendInChat(tester, 'tpyo here');
    await pickAction(tester, 'tpyo here', 'Edit');
    await tester.enterText(
      find.descendant(
        of: find.byType(MessageEditBar),
        matching: find.byType(TextField),
      ),
      'typo fixed',
    );
    await tester.tap(find.byIcon(Icons.check_circle));
    await waitFor(
      () async => (await bravoSees()).any((m) => m['text'] == 'typo fixed'),
      what: 'the edited text to reach smoke-b',
      tester: tester,
    );
    // An edited message keeps its menu.
    await pickAction(tester, 'typo fixed', 'Details');
    await letPopupsFinish(tester);
  });
}
