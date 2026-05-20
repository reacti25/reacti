// Unit tests for the user-search response models.
//
// Pins the JSON contract of `AllUserResponse` and its nested `Data`,
// `Datum` and `Pagination` records: field decoding, snake_case JSON keys,
// list handling, raw-JSON round-trips, `copyWith` overrides, and the
// null/missing-key tolerance each class actually exposes.

import 'dart:convert';

import 'package:achiar_expert_app/features/search/model/all_user_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AllUserResponse', () {
    test('fromJson decodes every field including the nested Data payload', () {
      final response = AllUserResponse.fromJson({
        "success": true,
        "message": "Found",
        "code": 200,
        "data": {
          "data": [
            {
              "id": 1,
              "full_name": "Ada Lovelace",
              "username": "ada",
              "avatar": "http://x/a.png",
              "is_friend": true,
              "is_request_sent": false,
            },
          ],
          "pagination": {
            "total": 1,
            "current_page": 1,
            "last_page": 1,
            "per_page": 15,
          },
        },
      });

      expect(response.success, isTrue);
      expect(response.message, 'Found');
      expect(response.code, 200);
      expect(response.data, isNotNull);
      expect(response.data!.data, hasLength(1));
      expect(response.data!.data!.first.fullName, 'Ada Lovelace');
      expect(response.data!.pagination!.total, 1);
    });

    test('fromJson keeps data null when the key is absent or null', () {
      expect(AllUserResponse.fromJson({}).data, isNull);
      expect(AllUserResponse.fromJson({"data": null}).data, isNull);
    });

    test('fromJson tolerates missing success, message and code keys', () {
      final response = AllUserResponse.fromJson({});

      expect(response.success, isNull);
      expect(response.message, isNull);
      expect(response.code, isNull);
      expect(response.data, isNull);
    });

    test('toJson emits the wrapper keys and the nested data map', () {
      final response = AllUserResponse(
        success: false,
        message: 'none',
        code: 404,
        data: Data(data: [], pagination: null),
      );

      final map = response.toJson();

      expect(map.keys, containsAll(['success', 'message', 'data', 'code']));
      expect(map['success'], isFalse);
      expect(map['message'], 'none');
      expect(map['code'], 404);
      expect(map['data'], isA<Map<String, dynamic>>());
    });

    test('toJson emits data as null when there is no payload', () {
      final map = AllUserResponse(success: true).toJson();

      expect(map['data'], isNull);
    });

    test('round-trips through raw JSON preserving key fields', () {
      final original = AllUserResponse(
        success: true,
        message: 'OK',
        code: 200,
        data: Data(
          data: [Datum(id: 9, username: 'grace')],
          pagination: Pagination(total: 1, currentPage: 1),
        ),
      );

      final restored = AllUserResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.data!.first.id, 9);
      expect(restored.data!.data!.first.username, 'grace');
      expect(restored.data!.pagination!.total, 1);
    });

    test('copyWith overrides only the named field', () {
      final original = AllUserResponse(
        success: true,
        message: 'm',
        code: 1,
        data: Data(),
      );

      final copy = original.copyWith(code: 2);

      expect(copy.code, 2);
      expect(copy.success, original.success);
      expect(copy.message, original.message);
      expect(copy.data, same(original.data));
    });
  });

  group('Data (search payload)', () {
    test('fromJson decodes the user list and pagination', () {
      final data = Data.fromJson({
        "data": [
          {"id": 1, "username": "a"},
          {"id": 2, "username": "b"},
        ],
        "pagination": {"total": 2},
      });

      expect(data.data, hasLength(2));
      expect(data.data![1].username, 'b');
      expect(data.pagination!.total, 2);
    });

    test('fromJson defaults data to an empty list when the key is missing', () {
      final data = Data.fromJson({});

      // Quirk: missing/null "data" decodes to [] (not null), while
      // "pagination" stays null.
      expect(data.data, isEmpty);
      expect(data.pagination, isNull);
    });

    test('fromJson defaults data to an empty list when the key is null', () {
      final data = Data.fromJson({"data": null});

      expect(data.data, isEmpty);
    });

    test('toJson emits an empty list when data is null', () {
      // Quirk: a null `data` field still serializes to [] rather than null.
      final map = Data(data: null, pagination: null).toJson();

      expect(map['data'], isEmpty);
      expect(map['pagination'], isNull);
    });

    test('toJson serializes the user list and pagination', () {
      final map =
          Data(
            data: [Datum(id: 3, username: 'c')],
            pagination: Pagination(total: 1),
          ).toJson();

      expect(map['data'], isA<List>());
      expect((map['data'] as List).first['id'], 3);
      expect((map['data'] as List).first['username'], 'c');
      expect(map['pagination'], isA<Map<String, dynamic>>());
    });

    test('round-trips through raw JSON preserving fields', () {
      final original = Data(
        data: [Datum(id: 1, fullName: 'X')],
        pagination: Pagination(total: 1, perPage: 10),
      );

      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.data!.first.id, 1);
      expect(restored.data!.first.fullName, 'X');
      expect(restored.pagination!.perPage, 10);
    });

    test('copyWith overrides only the named field', () {
      final original = Data(
        data: [Datum(id: 1)],
        pagination: Pagination(total: 1),
      );
      final newPagination = Pagination(total: 99);

      final copy = original.copyWith(pagination: newPagination);

      expect(copy.pagination, same(newPagination));
      expect(copy.data, same(original.data));
    });
  });

  group('Datum (search user)', () {
    test('fromJson maps snake_case keys onto camelCase fields', () {
      final datum = Datum.fromJson({
        "id": 42,
        "full_name": "Alan Turing",
        "username": "alan",
        "avatar": "http://x/t.png",
        "is_friend": false,
        "is_request_sent": true,
      });

      expect(datum.id, 42);
      expect(datum.fullName, 'Alan Turing');
      expect(datum.username, 'alan');
      expect(datum.avatar, 'http://x/t.png');
      expect(datum.isFriend, isFalse);
      expect(datum.isRequestSent, isTrue);
    });

    test('fromJson leaves every field null when keys are missing', () {
      final datum = Datum.fromJson({});

      expect(datum.id, isNull);
      expect(datum.fullName, isNull);
      expect(datum.username, isNull);
      expect(datum.avatar, isNull);
      expect(datum.isFriend, isNull);
      expect(datum.isRequestSent, isNull);
    });

    test('toJson emits the snake_case JSON keys', () {
      final map =
          Datum(
            id: 1,
            fullName: 'Name',
            username: 'handle',
            avatar: 'a.png',
            isFriend: true,
            isRequestSent: false,
          ).toJson();

      expect(map['id'], 1);
      expect(map['full_name'], 'Name');
      expect(map['username'], 'handle');
      expect(map['avatar'], 'a.png');
      expect(map['is_friend'], isTrue);
      expect(map['is_request_sent'], isFalse);
      expect(
        map.keys,
        containsAll([
          'id',
          'full_name',
          'username',
          'avatar',
          'is_friend',
          'is_request_sent',
        ]),
      );
    });

    test('round-trips through raw JSON preserving fields', () {
      final original = Datum(
        id: 7,
        fullName: 'F',
        username: 'u',
        avatar: 'v.png',
        isFriend: true,
        isRequestSent: true,
      );

      final restored = Datum.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.fullName, original.fullName);
      expect(restored.username, original.username);
      expect(restored.avatar, original.avatar);
      expect(restored.isFriend, original.isFriend);
      expect(restored.isRequestSent, original.isRequestSent);
    });

    test('copyWith overrides only the named field', () {
      final original = Datum(id: 1, username: 'old', isFriend: false);

      final copy = original.copyWith(isFriend: true);

      expect(copy.isFriend, isTrue);
      expect(copy.id, original.id);
      expect(copy.username, original.username);
    });
  });

  group('Pagination', () {
    test('fromJson maps snake_case keys onto camelCase fields', () {
      final pagination = Pagination.fromJson({
        "total": 100,
        "current_page": 2,
        "last_page": 7,
        "per_page": 15,
      });

      expect(pagination.total, 100);
      expect(pagination.currentPage, 2);
      expect(pagination.lastPage, 7);
      expect(pagination.perPage, 15);
    });

    test('fromJson leaves every field null when keys are missing', () {
      final pagination = Pagination.fromJson({});

      expect(pagination.total, isNull);
      expect(pagination.currentPage, isNull);
      expect(pagination.lastPage, isNull);
      expect(pagination.perPage, isNull);
    });

    test('toJson emits the snake_case JSON keys', () {
      final map =
          Pagination(
            total: 50,
            currentPage: 1,
            lastPage: 4,
            perPage: 12,
          ).toJson();

      expect(map['total'], 50);
      expect(map['current_page'], 1);
      expect(map['last_page'], 4);
      expect(map['per_page'], 12);
      expect(
        map.keys,
        containsAll(['total', 'current_page', 'last_page', 'per_page']),
      );
    });

    test('round-trips through raw JSON preserving fields', () {
      final original = Pagination(
        total: 9,
        currentPage: 3,
        lastPage: 9,
        perPage: 1,
      );

      final restored = Pagination.fromRawJson(original.toRawJson());

      expect(restored.total, original.total);
      expect(restored.currentPage, original.currentPage);
      expect(restored.lastPage, original.lastPage);
      expect(restored.perPage, original.perPage);
    });

    test('toRawJson produces a string that decodes to the toJson map', () {
      final pagination = Pagination(total: 1, currentPage: 1);

      expect(json.decode(pagination.toRawJson()), pagination.toJson());
    });

    test('copyWith overrides only the named field', () {
      final original = Pagination(
        total: 10,
        currentPage: 1,
        lastPage: 1,
        perPage: 10,
      );

      final copy = original.copyWith(currentPage: 2);

      expect(copy.currentPage, 2);
      expect(copy.total, original.total);
      expect(copy.lastPage, original.lastPage);
      expect(copy.perPage, original.perPage);
    });
  });
}
