// Unit tests for the chat_list_response.dart JSON DTOs.
//
// ChatListResponse is the envelope for the chat-list endpoint (the
// one-to-one and group conversations a user participates in). It nests
// Data (chats + pagination), a list of Chat preview rows, and
// Pagination. These are plain decoded-map DTOs, so the tests are pure
// and hermetic: they pin fromJson / toJson key mapping (snake_case JSON
// <-> camelCase Dart), round-trip stability, copyWith, and the model's
// null/missing quirks — notably that a missing `chats` key yields an
// EMPTY LIST rather than null.

import 'package:reacti_app/features/chat/model/chat_list_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat', () {
    final chatMap = <String, dynamic>{
      'type': 'group',
      'id': 3,
      'room_id': 88,
      'name': 'Engineering',
      'avatar': 'https://cdn.example.com/eng.png',
      'last_message': 'Ship it',
      'last_message_time': '2 min ago',
      'is_active': true,
      'member_count': 12,
    };

    test('fromJson parses every field', () {
      final chat = Chat.fromJson(chatMap);

      expect(chat.type, 'group');
      expect(chat.id, 3);
      expect(chat.roomId, 88);
      expect(chat.name, 'Engineering');
      expect(chat.avatar, 'https://cdn.example.com/eng.png');
      expect(chat.lastMessage, 'Ship it');
      expect(chat.lastMessageTime, '2 min ago');
      expect(chat.isActive, isTrue);
      expect(chat.memberCount, 12);
    });

    test('toJson emits snake_case keys', () {
      final json = Chat.fromJson(chatMap).toJson();

      expect(json['type'], 'group');
      expect(json['id'], 3);
      expect(json['room_id'], 88);
      expect(json['name'], 'Engineering');
      expect(json['avatar'], 'https://cdn.example.com/eng.png');
      expect(json['last_message'], 'Ship it');
      expect(json['last_message_time'], '2 min ago');
      expect(json['is_active'], true);
      expect(json['member_count'], 12);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Chat.fromJson(chatMap);
      final restored = Chat.fromRawJson(original.toRawJson());

      expect(restored.type, original.type);
      expect(restored.id, original.id);
      expect(restored.roomId, original.roomId);
      expect(restored.memberCount, original.memberCount);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Chat.fromJson(chatMap);
      final copy = original.copyWith(name: 'Renamed');

      expect(copy.name, 'Renamed');
      expect(copy.id, 3);
      expect(copy.type, 'group');
      expect(copy.memberCount, 12);
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final chat = Chat.fromJson(<String, dynamic>{});

      expect(chat.type, isNull);
      expect(chat.id, isNull);
      expect(chat.isActive, isNull);
      expect(chat.memberCount, isNull);
    });

    test('unreadCount defaults to 0 when absent (old backend)', () {
      expect(Chat.fromJson(<String, dynamic>{}).unreadCount, 0);
      expect(Chat.fromJson(chatMap).unreadCount, 0);
    });

    test('unreadCount parses when present and round-trips through toJson', () {
      final chat = Chat.fromJson({...chatMap, 'unread_count': 4});
      expect(chat.unreadCount, 4);
      expect(chat.toJson()['unread_count'], 4);
    });
  });

  group('Pagination', () {
    final paginationMap = <String, dynamic>{
      'total': 50,
      'current_page': 2,
      'last_page': 5,
      'per_page': 10,
    };

    test('fromJson parses every field', () {
      final pagination = Pagination.fromJson(paginationMap);

      expect(pagination.total, 50);
      expect(pagination.currentPage, 2);
      expect(pagination.lastPage, 5);
      expect(pagination.perPage, 10);
    });

    test('toJson emits snake_case keys', () {
      final json = Pagination.fromJson(paginationMap).toJson();

      expect(json['total'], 50);
      expect(json['current_page'], 2);
      expect(json['last_page'], 5);
      expect(json['per_page'], 10);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Pagination.fromJson(paginationMap);
      final restored = Pagination.fromRawJson(original.toRawJson());

      expect(restored.total, original.total);
      expect(restored.currentPage, original.currentPage);
      expect(restored.perPage, original.perPage);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Pagination.fromJson(paginationMap);
      final copy = original.copyWith(lastPage: 99);

      expect(copy.lastPage, 99);
      expect(copy.total, 50);
      expect(copy.currentPage, 2);
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final pagination = Pagination.fromJson(<String, dynamic>{});

      expect(pagination.total, isNull);
      expect(pagination.currentPage, isNull);
      expect(pagination.lastPage, isNull);
      expect(pagination.perPage, isNull);
    });
  });

  group('Data', () {
    final dataMap = <String, dynamic>{
      'chats': <dynamic>[
        <String, dynamic>{
          'type': 'private',
          'id': 1,
          'room_id': 10,
          'name': 'Bob',
          'avatar': null,
          'last_message': 'Hi',
          'last_message_time': 'now',
          'is_active': false,
          'member_count': 2,
        },
      ],
      'pagination': <String, dynamic>{
        'total': 1,
        'current_page': 1,
        'last_page': 1,
        'per_page': 10,
      },
    };

    test('fromJson parses the chats list and pagination', () {
      final data = Data.fromJson(dataMap);

      expect(data.chats, hasLength(1));
      expect(data.chats!.first.name, 'Bob');
      expect(data.pagination, isA<Pagination>());
      expect(data.pagination!.total, 1);
    });

    test('toJson emits snake_case keys with serialized list', () {
      final json = Data.fromJson(dataMap).toJson();

      expect(json['chats'], isA<List>());
      expect((json['chats'] as List), hasLength(1));
      expect(json['pagination'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Data.fromJson(dataMap);
      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.chats, hasLength(1));
      expect(restored.chats!.first.id, 1);
      expect(restored.pagination!.total, 1);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Data.fromJson(dataMap);
      final copy = original.copyWith(chats: <Chat>[]);

      expect(copy.chats, isEmpty);
      expect(copy.pagination, same(original.pagination));
    });

    test('fromJson missing chats yields an empty list, not null', () {
      // Quirk: the model defaults a missing `chats` key to [].
      final data = Data.fromJson(<String, dynamic>{'pagination': null});

      expect(data.chats, isNotNull);
      expect(data.chats, isEmpty);
      expect(data.pagination, isNull);
    });

    test('fromJson({}) yields an empty list and null pagination', () {
      final data = Data.fromJson(<String, dynamic>{});

      expect(data.chats, isEmpty);
      expect(data.pagination, isNull);
    });
  });

  group('ChatListResponse', () {
    final responseMap = <String, dynamic>{
      'success': true,
      'message': 'Chats fetched',
      'code': 200,
      'data': <String, dynamic>{
        'chats': <dynamic>[
          <String, dynamic>{
            'type': 'group',
            'id': 9,
            'room_id': 90,
            'name': 'Friends',
            'avatar': null,
            'last_message': 'See you',
            'last_message_time': 'yesterday',
            'is_active': true,
            'member_count': 4,
          },
        ],
        'pagination': <String, dynamic>{
          'total': 1,
          'current_page': 1,
          'last_page': 1,
          'per_page': 20,
        },
      },
    };

    test('fromJson parses the envelope and nested Data', () {
      final response = ChatListResponse.fromJson(responseMap);

      expect(response.success, isTrue);
      expect(response.message, 'Chats fetched');
      expect(response.code, 200);
      expect(response.data, isA<Data>());
      expect(response.data!.chats!.first.name, 'Friends');
    });

    test('toJson emits the envelope keys and serialized nested data', () {
      final json = ChatListResponse.fromJson(responseMap).toJson();

      expect(json['success'], true);
      expect(json['message'], 'Chats fetched');
      expect(json['code'], 200);
      expect(json['data'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = ChatListResponse.fromJson(responseMap);
      final restored = ChatListResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.chats!.first.id, 9);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = ChatListResponse.fromJson(responseMap);
      final copy = original.copyWith(message: 'updated');

      expect(copy.message, 'updated');
      expect(copy.success, isTrue);
      expect(copy.data, same(original.data));
    });

    test('fromJson guards a null data with a null nested object', () {
      final response = ChatListResponse.fromJson(<String, dynamic>{
        'success': false,
        'message': 'Error',
        'code': 500,
        'data': null,
      });

      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final response = ChatListResponse.fromJson(<String, dynamic>{});

      expect(response.success, isNull);
      expect(response.message, isNull);
      expect(response.code, isNull);
      expect(response.data, isNull);
    });
  });
}
