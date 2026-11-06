// Finding and typing inside an open 1:1 chat, shared by the chat journeys.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';

import 'wait.dart';

/// [text] inside the open chat (the chat list underneath shows previews too).
Finder inChat(String text) =>
    find.descendant(of: find.byType(InboxScreen), matching: find.text(text));

/// The open chat's message field.
final Finder chatComposer = find.descendant(
  of: find.byType(InboxScreen),
  matching: find.byType(TextFormField),
);

/// Types [text] in the open chat and taps send, once the send button has
/// stopped moving: the keyboard and the reply bar push the composer up after
/// typing starts, and a tap at the old position misses (nightly, 2026-11-05).
Future<void> sendInChat(WidgetTester tester, String text) async {
  await tester.enterText(chatComposer, text);
  final send = find.byKey(const Key('composer_send_button'));
  Offset? last;
  // waitFor pumps half a second between looks.
  await waitFor(
    () async {
      final now = tester.getCenter(send);
      final still = now == last;
      last = now;
      return still;
    },
    what: 'the send button to stop moving',
    tester: tester,
  );
  await tester.tap(send);
}
