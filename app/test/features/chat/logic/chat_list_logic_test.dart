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

  group('applyChatFilter', () {
    final chats = [
      Chat(name: 'Alice', type: 'single', unreadCount: 0),
      Chat(name: 'Devs', type: 'group', unreadCount: 3),
      Chat(name: 'Bob', type: 'single', unreadCount: 2),
      Chat(name: 'Family', type: 'group', unreadCount: 0),
    ];

    test('all returns everything', () {
      expect(applyChatFilter(chats, ChatFilter.all).length, 4);
    });

    test('direct keeps only non-group conversations', () {
      expect(applyChatFilter(chats, ChatFilter.direct).map((c) => c.name), [
        'Alice',
        'Bob',
      ]);
    });

    test('groups keeps only group conversations', () {
      expect(applyChatFilter(chats, ChatFilter.groups).map((c) => c.name), [
        'Devs',
        'Family',
      ]);
    });

    test('unseen keeps only conversations with unreadCount > 0', () {
      expect(applyChatFilter(chats, ChatFilter.unseen).map((c) => c.name), [
        'Devs',
        'Bob',
      ]);
    });
  });

  group('totalUnread', () {
    test('sums unreadCount across conversations', () {
      final chats = [
        Chat(unreadCount: 0),
        Chat(unreadCount: 3),
        Chat(unreadCount: 2),
      ];
      expect(totalUnread(chats), 5);
    });

    test('is 0 for an empty list', () {
      expect(totalUnread([]), 0);
    });
  });

  group('unseenConversationCount', () {
    test('counts conversations with anything unseen, not messages', () {
      final chats = [
        Chat(unreadCount: 0), // seen -> not counted
        Chat(unreadCount: 3), // one conversation
        Chat(unreadCount: 2), // one conversation
        Chat(unreadCount: 0), // seen -> not counted
      ];
      expect(unseenConversationCount(chats), 2);
    });

    test('is 0 when everything is seen', () {
      expect(
        unseenConversationCount([Chat(unreadCount: 0), Chat(unreadCount: 0)]),
        0,
      );
    });

    test('is 0 for an empty list', () {
      expect(unseenConversationCount([]), 0);
    });
  });
}
