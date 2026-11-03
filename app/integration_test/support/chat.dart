// Finding and typing inside an open 1:1 chat, shared by the chat journeys.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';

/// [text] inside the open chat (the chat list underneath shows previews too).
Finder inChat(String text) =>
    find.descendant(of: find.byType(InboxScreen), matching: find.text(text));

/// The open chat's message field.
final Finder chatComposer = find.descendant(
  of: find.byType(InboxScreen),
  matching: find.byType(TextFormField),
);

/// Types [text] in the open chat and taps send.
Future<void> sendInChat(WidgetTester tester, String text) async {
  await tester.enterText(chatComposer, text);
  await tester.tap(find.byKey(const Key('composer_send_button')));
}
