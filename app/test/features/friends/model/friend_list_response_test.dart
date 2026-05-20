// Unit tests for the friend_list_response.dart JSON DTOs.
//
// Pins the current parsing/serialisation behaviour of [FriendListResponse]
// and its nested [Datum] entry: fromJson/toJson key mapping, round-trips,
// copyWith semantics, and null/missing-field tolerance. Pure value-object
// tests — no HTTP, no Flutter widgets.

import 'package:reacti_app/features/friends/model/friend_list_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FriendListResponse', () {
    // A representative decoded server envelope with one friend entry.
    final fullJson = <String, dynamic>{
      "success": true,
      "message": "ok",
      "data": [
        {
          "id": 1,
          "name": "Alice",
          "username": "alice",
          "email": "alice@example.com",
          "phone": "555-0100",
          "avatar": "https://cdn/a.png",
        },
      ],
      "code": 200,
    };

    test('fromJson parses every envelope field and the nested data list', () {
      final res = FriendListResponse.fromJson(fullJson);

      expect(res.success, isTrue);
      expect(res.message, "ok");
      expect(res.code, 200);
      expect(res.data, hasLength(1));
      expect(res.data!.first.id, 1);
      expect(res.data!.first.name, "Alice");
      expect(res.data!.first.email, "alice@example.com");
    });

    test('toJson emits the expected keys and serialises nested data', () {
      final res = FriendListResponse(
        success: false,
        message: "err",
        code: 500,
        data: [Datum(id: 2, name: "Bob")],
      );
      final map = res.toJson();

      expect(map["success"], isFalse);
      expect(map["message"], "err");
      expect(map["code"], 500);
      expect(map["data"], isA<List<dynamic>>());
      expect((map["data"] as List).first, isA<Map<String, dynamic>>());
      expect((map["data"] as List).first["id"], 2);
    });

    test('round-trips through fromRawJson(toRawJson(x)) preserving fields', () {
      final original = FriendListResponse.fromJson(fullJson);
      final restored = FriendListResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.first.id, original.data!.first.id);
      expect(restored.data!.first.email, original.data!.first.email);
    });

    test('copyWith overrides only the supplied field', () {
      final original = FriendListResponse.fromJson(fullJson);
      final copy = original.copyWith(message: "changed");

      expect(copy.message, "changed");
      // Untouched fields are carried over unchanged.
      expect(copy.success, original.success);
      expect(copy.code, original.code);
      expect(copy.data, same(original.data));
    });

    test('fromJson({}) normalises a missing data field to an empty list', () {
      final res = FriendListResponse.fromJson({});

      expect(res.success, isNull);
      expect(res.message, isNull);
      expect(res.code, isNull);
      // Quirk: `data` is never null — a missing/null value becomes [].
      expect(res.data, isEmpty);
    });

    test('toJson serialises a null data field as an empty list', () {
      // Quirk: even when `data` is null on the object, toJson emits [].
      final map = FriendListResponse().toJson();

      expect(map["data"], isEmpty);
    });
  });

  group('Datum', () {
    final datumJson = <String, dynamic>{
      "id": 7,
      "name": "Carol",
      "username": "carol",
      "email": "carol@example.com",
      "phone": "555-0199",
      "avatar": "https://cdn/c.png",
    };

    test('fromJson parses every field', () {
      final d = Datum.fromJson(datumJson);

      expect(d.id, 7);
      expect(d.name, "Carol");
      expect(d.username, "carol");
      expect(d.email, "carol@example.com");
      expect(d.phone, "555-0199");
      expect(d.avatar, "https://cdn/c.png");
    });

    test('toJson emits all keys with their values', () {
      final map = Datum.fromJson(datumJson).toJson();

      expect(
        map.keys,
        containsAll(<String>[
          "id",
          "name",
          "username",
          "email",
          "phone",
          "avatar",
        ]),
      );
      expect(map["name"], "Carol");
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Datum.fromJson(datumJson);
      final restored = Datum.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.username, original.username);
      expect(restored.avatar, original.avatar);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Datum.fromJson(datumJson);
      final copy = original.copyWith(name: "Dave");

      expect(copy.name, "Dave");
      expect(copy.id, original.id);
      expect(copy.email, original.email);
    });

    test('fromJson({}) leaves every field null', () {
      final d = Datum.fromJson({});

      expect(d.id, isNull);
      expect(d.name, isNull);
      expect(d.username, isNull);
      expect(d.email, isNull);
      expect(d.phone, isNull);
      expect(d.avatar, isNull);
    });

    test('username tolerates a null dynamic value', () {
      // `username` is typed dynamic; a JSON null is preserved as-is.
      final d = Datum.fromJson({"id": 1, "username": null});

      expect(d.username, isNull);
      expect(d.toJson()["username"], isNull);
    });
  });
}
