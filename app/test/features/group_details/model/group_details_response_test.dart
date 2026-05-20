// Unit tests for the group_details_response.dart JSON DTOs.
//
// Pins the current parsing/serialisation behaviour of [GroupDetailsResponse]
// and its nested [Data], [Group], [Creator] and [Member] classes:
// snake_case key mapping, round-trips, copyWith semantics, and the
// null/missing-field tolerances each factory bakes in.

import 'package:achiar_expert_app/features/group_details/model/group_details_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A representative creator/user profile reused for creator and member.
  final creatorJson = <String, dynamic>{
    "id": 5,
    "first_name": "Owner",
    "last_name": "One",
    "email": "owner@example.com",
    "avatar": "https://cdn/o.png",
    "last_activity_at": "2026-01-02T00:00:00Z",
  };

  // A fully populated decoded server envelope reused across the groups.
  final fullJson = <String, dynamic>{
    "success": true,
    "message": "ok",
    "code": 200,
    "data": {
      "group": {
        "id": 42,
        "name": "Trip",
        "description": "Holiday plans",
        "avatar": "https://cdn/g.png",
        "is_admin": true,
        "member_count": 2,
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-05T00:00:00Z",
        "creator": creatorJson,
        "members": [
          {
            "id": 100,
            "role": "owner",
            "joined_at": "2026-01-01T00:00:00Z",
            "user": creatorJson,
          },
        ],
      },
    },
  };

  group('GroupDetailsResponse', () {
    test('fromJson parses the envelope and nested Data payload', () {
      final res = GroupDetailsResponse.fromJson(fullJson);

      expect(res.success, isTrue);
      expect(res.message, "ok");
      expect(res.code, 200);
      expect(res.data, isNotNull);
      expect(res.data!.group!.id, 42);
    });

    test('toJson emits envelope keys and delegates to data.toJson', () {
      final map = GroupDetailsResponse.fromJson(fullJson).toJson();

      expect(map["success"], isTrue);
      expect(map["message"], "ok");
      expect(map["code"], 200);
      expect(map["data"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = GroupDetailsResponse.fromJson(fullJson);
      final restored = GroupDetailsResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.code, original.code);
      expect(restored.data!.group!.name, "Trip");
    });

    test('copyWith overrides only the supplied field', () {
      final original = GroupDetailsResponse.fromJson(fullJson);
      final copy = original.copyWith(message: "changed");

      expect(copy.message, "changed");
      expect(copy.success, original.success);
      expect(copy.data, same(original.data));
    });

    test('fromJson({}) yields a null data and toJson emits null data', () {
      final res = GroupDetailsResponse.fromJson({});

      expect(res.data, isNull);
      expect(res.toJson()["data"], isNull);
    });
  });

  group('Data', () {
    test('fromJson parses the nested group', () {
      final data = Data.fromJson(fullJson["data"]);

      expect(data.group, isNotNull);
      expect(data.group!.memberCount, 2);
    });

    test('toJson serialises group via group.toJson', () {
      final map = Data.fromJson(fullJson["data"]).toJson();

      expect(map["group"], isA<Map<String, dynamic>>());
      expect((map["group"] as Map)["id"], 42);
    });

    test('fromJson({}) guards a missing group to null', () {
      final data = Data.fromJson({});

      expect(data.group, isNull);
      expect(data.toJson()["group"], isNull);
    });

    test('copyWith overrides the group field', () {
      final original = Data.fromJson(fullJson["data"]);
      final copy = original.copyWith(group: Group(id: 7));

      expect(copy.group!.id, 7);
    });
  });

  group('Group', () {
    final groupJson = fullJson["data"]["group"] as Map<String, dynamic>;

    test('fromJson maps snake_case keys and parses nested objects', () {
      final g = Group.fromJson(groupJson);

      expect(g.id, 42);
      expect(g.name, "Trip");
      expect(g.description, "Holiday plans");
      expect(g.avatar, "https://cdn/g.png");
      expect(g.isAdmin, isTrue);
      expect(g.memberCount, 2);
      expect(g.createdAt, "2026-01-01T00:00:00Z");
      expect(g.updatedAt, "2026-01-05T00:00:00Z");
      expect(g.creator, isNotNull);
      expect(g.creator!.email, "owner@example.com");
      expect(g.members, hasLength(1));
      expect(g.members!.first.role, "owner");
    });

    test('toJson emits snake_case keys and serialises nested objects', () {
      final map = Group.fromJson(groupJson).toJson();

      expect(map["is_admin"], isTrue);
      expect(map["member_count"], 2);
      expect(map["created_at"], "2026-01-01T00:00:00Z");
      expect(map["updated_at"], "2026-01-05T00:00:00Z");
      expect(map["creator"], isA<Map<String, dynamic>>());
      expect(map["members"], isA<List<dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Group.fromJson(groupJson);
      final restored = Group.fromRawJson(original.toRawJson());

      expect(restored.id, 42);
      expect(restored.isAdmin, isTrue);
      expect(restored.creator!.firstName, "Owner");
      expect(restored.members!.first.user!.id, 5);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Group.fromJson(groupJson);
      final copy = original.copyWith(name: "Renamed");

      expect(copy.name, "Renamed");
      expect(copy.id, original.id);
      expect(copy.members, same(original.members));
    });

    test(
      'fromJson({}) normalises members to [] and guards creator to null',
      () {
        final g = Group.fromJson({});

        // Quirk: missing `members` becomes [], missing `creator` stays null.
        expect(g.members, isEmpty);
        expect(g.creator, isNull);
        expect(g.id, isNull);
      },
    );

    test('toJson serialises a null members field as an empty list', () {
      final map = Group().toJson();

      expect(map["members"], isEmpty);
      expect(map["creator"], isNull);
    });
  });

  group('Creator', () {
    test('fromJson maps snake_case keys onto camelCase fields', () {
      final c = Creator.fromJson(creatorJson);

      expect(c.id, 5);
      expect(c.firstName, "Owner");
      expect(c.lastName, "One");
      expect(c.email, "owner@example.com");
      expect(c.avatar, "https://cdn/o.png");
      expect(c.lastActivityAt, "2026-01-02T00:00:00Z");
    });

    test('toJson emits snake_case keys', () {
      final map = Creator.fromJson(creatorJson).toJson();

      expect(map["first_name"], "Owner");
      expect(map["last_name"], "One");
      expect(map["last_activity_at"], "2026-01-02T00:00:00Z");
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Creator.fromJson(creatorJson);
      final restored = Creator.fromRawJson(original.toRawJson());

      expect(restored.id, 5);
      expect(restored.email, "owner@example.com");
      expect(restored.lastActivityAt, "2026-01-02T00:00:00Z");
    });

    test('copyWith overrides only the supplied field', () {
      final copy = Creator.fromJson(creatorJson).copyWith(email: "new@x.com");

      expect(copy.email, "new@x.com");
      expect(copy.firstName, "Owner");
      expect(copy.id, 5);
    });

    test('fromJson({}) leaves every field null', () {
      final c = Creator.fromJson({});

      expect(c.id, isNull);
      expect(c.firstName, isNull);
      expect(c.lastName, isNull);
      expect(c.email, isNull);
      expect(c.avatar, isNull);
      expect(c.lastActivityAt, isNull);
    });
  });

  group('Member', () {
    final memberJson =
        (fullJson["data"]["group"]["members"] as List).first
            as Map<String, dynamic>;

    test('fromJson maps keys and parses the nested user Creator', () {
      final m = Member.fromJson(memberJson);

      expect(m.id, 100);
      expect(m.role, "owner");
      expect(m.joinedAt, "2026-01-01T00:00:00Z");
      expect(m.user, isNotNull);
      expect(m.user!.id, 5);
    });

    test('toJson emits snake_case keys and serialises the user', () {
      final map = Member.fromJson(memberJson).toJson();

      expect(map["id"], 100);
      expect(map["role"], "owner");
      expect(map["joined_at"], "2026-01-01T00:00:00Z");
      expect(map["user"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Member.fromJson(memberJson);
      final restored = Member.fromRawJson(original.toRawJson());

      expect(restored.id, 100);
      expect(restored.role, "owner");
      expect(restored.user!.email, "owner@example.com");
    });

    test('copyWith overrides only the supplied field', () {
      final original = Member.fromJson(memberJson);
      final copy = original.copyWith(role: "member");

      expect(copy.role, "member");
      expect(copy.id, original.id);
      expect(copy.user, same(original.user));
    });

    test('fromJson({}) guards a missing user to null', () {
      final m = Member.fromJson({});

      expect(m.user, isNull);
      expect(m.id, isNull);
      expect(m.role, isNull);
      expect(m.joinedAt, isNull);
    });
  });
}
