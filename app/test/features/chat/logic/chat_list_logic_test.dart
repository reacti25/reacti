// Unit tests for the pure conversations-screen logic.
//
// FP2 of the frontend refactor extracts side-effect-free logic out of
// the fat chat widgets into testable units. This file tests the first
// such extraction from ChatScreen: the time-based greeting and the
// chat-name filter.

import 'package:reacti_app/features/chat/logic/chat_list_logic.dart';
import 'package:reacti_app/features/chat/model/chat_list_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timeBasedGreeting', () {
    test('returns Good Morning for 05:00–11:59', () {
      expect(timeBasedGreeting(5), 'Good Morning');
      expect(timeBasedGreeting(8), 'Good Morning');
      expect(timeBasedGreeting(11), 'Good Morning');
    });

    test('returns Good Afternoon for 12:00–16:59', () {
      expect(timeBasedGreeting(12), 'Good Afternoon');
      expect(timeBasedGreeting(16), 'Good Afternoon');
    });

    test('returns Good Evening for 17:00–20:59', () {
      expect(timeBasedGreeting(17), 'Good Evening');
      expect(timeBasedGreeting(20), 'Good Evening');
    });

    test('returns Good Night for the late/early hours', () {
      expect(timeBasedGreeting(21), 'Good Night');
      expect(timeBasedGreeting(23), 'Good Night');
      expect(timeBasedGreeting(0), 'Good Night');
      expect(timeBasedGreeting(4), 'Good Night');
    });
  });

  group('filterChatsByName', () {
    final chats = [
      Chat(name: 'Alice'),
      Chat(name: 'Bob'),
      Chat(name: 'alicia keys'),
    ];

    test('matches names case-insensitively', () {
      final result = filterChatsByName(chats, 'ali');
      expect(result.map((c) => c.name), ['Alice', 'alicia keys']);
    });

    test('an empty query returns every chat', () {
      expect(filterChatsByName(chats, '').length, 3);
    });

    test('returns an empty list when nothing matches', () {
      expect(filterChatsByName(chats, 'zzz'), isEmpty);
    });

    test('preserves the original order of matches', () {
      final result = filterChatsByName(chats, 'a');
      expect(result.map((c) => c.name), ['Alice', 'alicia keys']);
    });
  });
}
