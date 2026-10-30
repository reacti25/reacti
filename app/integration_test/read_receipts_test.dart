// Read receipts on a device, against the throwaway test server: opening a
// chat tells the sender it was read; the sender's own message turns to two
// ticks live when it is read; and with receipts turned off in Settings,
// nobody is told. Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/chat.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// The read ticks (two) showing in the open chat.
int readTicks() =>
    find
        .descendant(
          of: find.byType(InboxScreen),
          matching: find.byIcon(Icons.done_all),
        )
        .evaluate()
        .length;

/// Profile → Settings → Read Receipts: flips the switch, then back to Chat.
Future<void> flipReadReceipts(WidgetTester tester) async {
  await tester.tap(find.text('Profile').last);
  await pumpUntilFound(tester, find.text('Settings'));
  await tester.ensureVisible(find.text('Settings'));
  await tester.tap(find.text('Settings'));
  await pumpUntilFound(tester, find.text('Read Receipts'));
  await tester.tap(find.text('Read Receipts'));
  final toggle = find.byKey(const Key('read_receipts_switch'));
  await pumpUntilFound(tester, toggle);
  await tester.tap(toggle);
  await tester.pump(const Duration(seconds: 2)); // saved on the server
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(seconds: 1));
  await tester.binding.handlePopRoute();
  await pumpUntilFound(tester, find.text('Chat'));
  await tester.tap(find.text('Chat').last);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('read receipts both ways, and off', (tester) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    addTearDown(() => alpha.setReadReceipts(true));
    Future<String?> statusOf(String text) async =>
        (await bravo.conversation(
              alpha.id,
            )).lastWhere((m) => m['text'] == text)['status']
            as String?;

    // smoke-b's message: opening the chat marks it read.
    await bravo.sendText(alpha.id, 'did you read this');
    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await letPopupsFinish(tester);
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, inChat('did you read this'));
    await waitFor(
      () async => await statusOf('did you read this') == 'read',
      what: 'smoke-b to see the message as read',
      tester: tester,
    );

    // Alpha's message: smoke-b reads it, the ticks turn double live.
    await sendInChat(tester, 'read mine');
    await tester.pump(const Duration(seconds: 2));
    final before = readTicks();
    await bravo.conversation(alpha.id); // opening the chat reads it
    await waitFor(
      () async => readTicks() > before,
      what: "alpha's message to show two ticks",
      tester: tester,
    );

    // Receipts off: opening a chat no longer tells the sender.
    await tester.binding.handlePopRoute();
    await waitFor(
      () async => find.byType(InboxScreen).evaluate().isEmpty,
      what: 'the chat to close',
      tester: tester,
    );
    await flipReadReceipts(tester);
    await bravo.sendText(alpha.id, 'private read');
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));
    await pumpUntilFound(tester, inChat('private read'));
    await tester.pump(const Duration(seconds: 3));
    expect(await statusOf('private read'), isNot('read'));
    await letPopupsFinish(tester);
  });
}
