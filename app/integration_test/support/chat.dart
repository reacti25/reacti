// Finding, typing and long-pressing inside an open chat (1:1 or group), shared
// by the chat journeys.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';

import 'wait.dart';

/// The open chat screen: a 1:1 chat or a group (a journey has one open at a
/// time).
final Finder _openChat = find.byWidgetPredicate(
  (w) => w is InboxScreen || w is GroupInboxScreen,
);

/// [text] inside the open chat (the chat list underneath shows previews too).
Finder inChat(String text) =>
    find.descendant(of: _openChat, matching: find.text(text));

/// The open chat's message field.
final Finder chatComposer = find.descendant(
  of: _openChat,
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
