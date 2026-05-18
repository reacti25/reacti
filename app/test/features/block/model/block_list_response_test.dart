// Unit tests for the block_list_response.dart JSON DTOs.
//
// BlockListResponse is the envelope for the blocked-user-list endpoint.
// It nests Data (the paginated payload), which holds a list of
// BlockedUserElement entries — each carrying a BlockedUserBlockedUser
// profile — plus Pagination metadata. These are plain decoded-map DTOs,
// so the tests are pure and hermetic: they pin fromJson / toJson key
// mapping, round-trip stability, copyWith, and the model's null/missing
// quirks exactly as written (notably: a missing `blocked_users` key
// yields an EMPTY LIST, not null).

import 'package:achiar_expert_app/features/block/model/block_list_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockedUserBlockedUser', () {
    final profileMap = <String, dynamic>{
      'id': 11,
      'full_name': 'Alan Turing',
      'first_name': 'Alan',
      'last_name': 'Turing',
      'username': 'alan',
      'avatar': 'https://cdn.example.com/alan.png',
    };

    test('fromJson parses every field', () {
      final profile = BlockedUserBlockedUser.fromJson(profileMap);

      expect(profile.id, 11);
      expect(profile.fullName, 'Alan Turing');
      expect(profile.firstName, 'Alan');
      expect(profile.lastName, 'Turing');
      expect(profile.username, 'alan');
      expect(profile.avatar, 'https://cdn.example.com/alan.png');
    });

    test('toJson emits snake_case keys', () {
      final json = BlockedUserBlockedUser.fromJson(profileMap).toJson();

      expect(json['id'], 11);
      expect(json['full_name'], 'Alan Turing');
      expect(json['first_name'], 'Alan');
      expect(json['last_name'], 'Turing');
      expect(json['username'], 'alan');
      expect(json['avatar'], 'https://cdn.example.com/alan.png');
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = BlockedUserBlockedUser.fromJson(profileMap);
      final restored =
          BlockedUserBlockedUser.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.fullName, original.fullName);
      expect(restored.avatar, original.avatar);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = BlockedUserBlockedUser.fromJson(profileMap);
      final copy = original.copyWith(fullName: 'Renamed');

      expect(copy.fullName, 'Renamed');
      expect(copy.id, 11);
      expect(copy.username, 'alan');
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final profile = BlockedUserBlockedUser.fromJson(<String, dynamic>{});

      expect(profile.id, isNull);
      expect(profile.fullName, isNull);
      expect(profile.avatar, isNull);
    });
  });

  group('BlockedUserElement', () {
    final elementMap = <String, dynamic>{
      'id': 5,
      'block_user_id': 11,
      'created_at': '2026-05-16T10:00:00.000Z',
      'blocked_user': <String, dynamic>{
        'id': 11,
        'full_name': 'Alan Turing',
        'first_name': 'Alan',
        'last_name': 'Turing',
        'username': 'alan',
        'avatar': null,
      },
    };

    test('fromJson parses fields and the nested blocked_user', () {
      final element = BlockedUserElement.fromJson(elementMap);

      expect(element.id, 5);
      expect(element.blockUserId, 11);
      // created_at stays a raw String — it is NOT parsed to DateTime here.
      expect(element.createdAt, '2026-05-16T10:00:00.000Z');
      expect(element.blockedUser, isA<BlockedUserBlockedUser>());
      expect(element.blockedUser!.username, 'alan');
    });

    test('toJson emits snake_case keys and serialized nested object', () {
      final json = BlockedUserElement.fromJson(elementMap).toJson();

      expect(json['id'], 5);
      expect(json['block_user_id'], 11);
      expect(json['created_at'], '2026-05-16T10:00:00.000Z');
      expect(json['blocked_user'], isA<Map<String, dynamic>>());
      expect((json['blocked_user'] as Map)['username'], 'alan');
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = BlockedUserElement.fromJson(elementMap);
      final restored = BlockedUserElement.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.blockUserId, original.blockUserId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.blockedUser!.id, original.blockedUser!.id);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = BlockedUserElement.fromJson(elementMap);
      final copy = original.copyWith(blockUserId: 99);

      expect(copy.blockUserId, 99);
      expect(copy.id, 5);
      expect(copy.blockedUser, same(original.blockedUser));
    });

    test('fromJson guards a null blocked_user with a null nested object', () {
      final element = BlockedUserElement.fromJson(<String, dynamic>{
        'id': 5,
        'block_user_id': 11,
        'created_at': null,
        'blocked_user': null,
      });

      expect(element.id, 5);
      expect(element.createdAt, isNull);
      expect(element.blockedUser, isNull);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final element = BlockedUserElement.fromJson(<String, dynamic>{});

      expect(element.id, isNull);
      expect(element.blockUserId, isNull);
      expect(element.blockedUser, isNull);
    });
  });

  group('Pagination', () {
    final paginationMap = <String, dynamic>{
      'total': 30,
      'current_page': 2,
      'last_page': 3,
      'per_page': 10,
    };

    test('fromJson parses every field', () {
      final pagination = Pagination.fromJson(paginationMap);

      expect(pagination.total, 30);
      expect(pagination.currentPage, 2);
      expect(pagination.lastPage, 3);
      expect(pagination.perPage, 10);
    });

    test('toJson emits snake_case keys', () {
      final json = Pagination.fromJson(paginationMap).toJson();

      expect(json['total'], 30);
      expect(json['current_page'], 2);
      expect(json['last_page'], 3);
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
      final copy = original.copyWith(currentPage: 1);

      expect(copy.currentPage, 1);
      expect(copy.total, 30);
      expect(copy.lastPage, 3);
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
      'blocked_users': <dynamic>[
        <String, dynamic>{
          'id': 5,
          'block_user_id': 11,
          'created_at': '2026-05-16T10:00:00.000Z',
          'blocked_user': <String, dynamic>{
            'id': 11,
            'full_name': 'Alan Turing',
            'first_name': 'Alan',
            'last_name': 'Turing',
            'username': 'alan',
            'avatar': null,
          },
        },
      ],
      'pagination': <String, dynamic>{
        'total': 1,
        'current_page': 1,
        'last_page': 1,
        'per_page': 10,
      },
    };

    test('fromJson parses the blocked_users list and pagination', () {
      final data = Data.fromJson(dataMap);

      expect(data.blockedUsers, hasLength(1));
      expect(data.blockedUsers!.first.id, 5);
      expect(data.blockedUsers!.first.blockedUser!.username, 'alan');
      expect(data.pagination, isA<Pagination>());
      expect(data.pagination!.total, 1);
    });

    test('toJson emits snake_case keys with serialized list', () {
      final json = Data.fromJson(dataMap).toJson();

      expect(json['blocked_users'], isA<List>());
      expect((json['blocked_users'] as List), hasLength(1));
      expect(json['pagination'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Data.fromJson(dataMap);
      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.blockedUsers, hasLength(1));
      expect(restored.blockedUsers!.first.id, 5);
      expect(restored.pagination!.total, 1);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Data.fromJson(dataMap);
      final copy = original.copyWith(blockedUsers: <BlockedUserElement>[]);

      expect(copy.blockedUsers, isEmpty);
      expect(copy.pagination, same(original.pagination));
    });

    test('fromJson missing blocked_users yields an empty list, not null', () {
      // Quirk: the model defaults a missing `blocked_users` key to [].
      final data = Data.fromJson(<String, dynamic>{'pagination': null});

      expect(data.blockedUsers, isNotNull);
      expect(data.blockedUsers, isEmpty);
      expect(data.pagination, isNull);
    });

    test('fromJson({}) yields an empty list and null pagination', () {
      final data = Data.fromJson(<String, dynamic>{});

      expect(data.blockedUsers, isEmpty);
      expect(data.pagination, isNull);
    });
  });

  group('BlockListResponse', () {
    final responseMap = <String, dynamic>{
      'success': true,
      'message': 'Blocked users fetched',
      'code': 200,
      'data': <String, dynamic>{
        'blocked_users': <dynamic>[],
        'pagination': <String, dynamic>{
          'total': 0,
          'current_page': 1,
          'last_page': 1,
          'per_page': 10,
        },
      },
    };

    test('fromJson parses the envelope and nested Data', () {
      final response = BlockListResponse.fromJson(responseMap);

      expect(response.success, isTrue);
      expect(response.message, 'Blocked users fetched');
      expect(response.code, 200);
      expect(response.data, isA<Data>());
      expect(response.data!.blockedUsers, isEmpty);
      expect(response.data!.pagination!.total, 0);
    });

    test('toJson emits the envelope keys and serialized nested data', () {
      final json = BlockListResponse.fromJson(responseMap).toJson();

      expect(json['success'], true);
      expect(json['message'], 'Blocked users fetched');
      expect(json['code'], 200);
      expect(json['data'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = BlockListResponse.fromJson(responseMap);
      final restored = BlockListResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.pagination!.total, 0);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = BlockListResponse.fromJson(responseMap);
      final copy = original.copyWith(code: 500);

      expect(copy.code, 500);
      expect(copy.success, isTrue);
      expect(copy.data, same(original.data));
    });

    test('fromJson guards a null data with a null nested object', () {
      final response = BlockListResponse.fromJson(<String, dynamic>{
        'success': false,
        'message': 'Forbidden',
        'code': 403,
        'data': null,
      });

      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final response = BlockListResponse.fromJson(<String, dynamic>{});

      expect(response.success, isNull);
      expect(response.message, isNull);
      expect(response.code, isNull);
      expect(response.data, isNull);
    });
  });
}
