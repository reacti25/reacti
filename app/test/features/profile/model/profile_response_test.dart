// Unit tests for the profile_response.dart JSON DTOs.
//
// Pins the current parsing/serialisation behaviour of [ProfileResponse] and
// its nested [Data] profile payload: snake_case key mapping, round-trips,
// copyWith semantics, and null/missing-field tolerance.

import 'package:reacti_app/features/profile/model/profile_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fully populated decoded server envelope reused across the groups.
  final fullJson = <String, dynamic>{
    "success": true,
    "message": "ok",
    "code": 200,
    "data": {
      "id": 1,
      "full_name": "Alice Adams",
      "first_name": "Alice",
      "last_name": "Adams",
      "username": "alice",
      "email": "alice@example.com",
      "bio": "Hello there",
      "phone": "555-0100",
      "avatar": "https://cdn/a.png",
      "total_friends": 12,
      "total_groups": 3,
      "created_at": "2026-01-01T00:00:00Z",
    },
  };

  group('ProfileResponse', () {
    test('fromJson parses the envelope and nested Data payload', () {
      final res = ProfileResponse.fromJson(fullJson);

      expect(res.success, isTrue);
      expect(res.message, "ok");
      expect(res.code, 200);
      expect(res.data, isNotNull);
      expect(res.data!.id, 1);
      expect(res.data!.fullName, "Alice Adams");
    });

    test('toJson emits envelope keys and delegates to data.toJson', () {
      final map = ProfileResponse.fromJson(fullJson).toJson();

      expect(map["success"], isTrue);
      expect(map["message"], "ok");
      expect(map["code"], 200);
      expect(map["data"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = ProfileResponse.fromJson(fullJson);
      final restored = ProfileResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.code, original.code);
      expect(restored.data!.username, "alice");
      expect(restored.data!.totalFriends, 12);
    });

    test('copyWith overrides only the supplied field', () {
      final original = ProfileResponse.fromJson(fullJson);
      final copy = original.copyWith(message: "changed");

      expect(copy.message, "changed");
      expect(copy.success, original.success);
      expect(copy.data, same(original.data));
    });

    test('fromJson({}) yields a null data and toJson emits null data', () {
      final res = ProfileResponse.fromJson({});

      expect(res.data, isNull);
      expect(res.toJson()["data"], isNull);
    });
  });

  group('Data', () {
    final dataJson = fullJson["data"] as Map<String, dynamic>;

    test('fromJson maps snake_case keys onto camelCase fields', () {
      final d = Data.fromJson(dataJson);

      expect(d.id, 1);
      expect(d.fullName, "Alice Adams");
      expect(d.firstName, "Alice");
      expect(d.lastName, "Adams");
      expect(d.username, "alice");
      expect(d.email, "alice@example.com");
      expect(d.bio, "Hello there");
      expect(d.phone, "555-0100");
      expect(d.avatar, "https://cdn/a.png");
      expect(d.totalFriends, 12);
      expect(d.totalGroups, 3);
      expect(d.createdAt, "2026-01-01T00:00:00Z");
    });

    test('toJson emits snake_case keys', () {
      final map = Data.fromJson(dataJson).toJson();

      expect(map["full_name"], "Alice Adams");
      expect(map["first_name"], "Alice");
      expect(map["last_name"], "Adams");
      expect(map["total_friends"], 12);
      expect(map["total_groups"], 3);
      expect(map["created_at"], "2026-01-01T00:00:00Z");
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Data.fromJson(dataJson);
      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.id, 1);
      expect(restored.email, "alice@example.com");
      expect(restored.bio, "Hello there");
      expect(restored.totalGroups, 3);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Data.fromJson(dataJson);
      final copy = original.copyWith(username: "alice2");

      expect(copy.username, "alice2");
      expect(copy.id, original.id);
      expect(copy.email, original.email);
    });

    test('fromJson({}) leaves every field null', () {
      final d = Data.fromJson({});

      expect(d.id, isNull);
      expect(d.fullName, isNull);
      expect(d.firstName, isNull);
      expect(d.lastName, isNull);
      expect(d.username, isNull);
      expect(d.email, isNull);
      expect(d.bio, isNull);
      expect(d.phone, isNull);
      expect(d.avatar, isNull);
      expect(d.totalFriends, isNull);
      expect(d.totalGroups, isNull);
      expect(d.createdAt, isNull);
    });

    test('bio tolerates a null dynamic value', () {
      // `bio` is typed dynamic; a JSON null is preserved as-is.
      final d = Data.fromJson({"id": 1, "bio": null});

      expect(d.bio, isNull);
      expect(d.toJson()["bio"], isNull);
    });
  });
}
