// Unit tests for the group_media_response.dart JSON DTOs.
//
// Pins the current parsing/serialisation behaviour of [GroupMediaResponse]
// and its nested [Data], [Media], [Sender] and [Pagination] classes:
// snake_case key mapping, round-trips, copyWith semantics, and the
// null/missing-field tolerances each factory bakes in.

import 'package:achiar_expert_app/features/group_details/model/group_media_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fully populated decoded server envelope reused across the groups.
  final fullJson = <String, dynamic>{
    "success": true,
    "message": "ok",
    "code": 200,
    "data": {
      "media": [
        {
          "id": 7,
          "file_url": "https://cdn/m.jpg",
          "file_type": "image",
          "sent_at": "2026-01-01T00:00:00Z",
          "sender": {"id": 3, "name": "Sam", "avatar": "https://cdn/s.png"},
        },
      ],
      "pagination": {
        "total": 1,
        "current_page": 1,
        "last_page": 1,
        "per_page": 30,
      },
    },
  };

  group('GroupMediaResponse', () {
    test('fromJson parses the envelope and nested Data payload', () {
      final res = GroupMediaResponse.fromJson(fullJson);

      expect(res.success, isTrue);
      expect(res.message, "ok");
      expect(res.code, 200);
      expect(res.data, isNotNull);
      expect(res.data!.media, hasLength(1));
      expect(res.data!.pagination!.total, 1);
    });

    test('toJson emits envelope keys and delegates to data.toJson', () {
      final map = GroupMediaResponse.fromJson(fullJson).toJson();

      expect(map["success"], isTrue);
      expect(map["message"], "ok");
      expect(map["code"], 200);
      expect(map["data"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = GroupMediaResponse.fromJson(fullJson);
      final restored = GroupMediaResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.code, original.code);
      expect(restored.data!.media!.first.id, 7);
      expect(restored.data!.pagination!.perPage, 30);
    });

    test('copyWith overrides only the supplied field', () {
      final original = GroupMediaResponse.fromJson(fullJson);
      final copy = original.copyWith(code: 204);

      expect(copy.code, 204);
      expect(copy.success, original.success);
      expect(copy.data, same(original.data));
    });

    test('fromJson({}) yields a null data and toJson emits null data', () {
      final res = GroupMediaResponse.fromJson({});

      expect(res.data, isNull);
      expect(res.toJson()["data"], isNull);
    });
  });

  group('Data', () {
    test('fromJson parses the media list and pagination', () {
      final data = Data.fromJson(fullJson["data"]);

      expect(data.media, hasLength(1));
      expect(data.media!.first.fileType, "image");
      expect(data.pagination!.currentPage, 1);
    });

    test('toJson serialises media as a list and pagination as a map', () {
      final map = Data.fromJson(fullJson["data"]).toJson();

      expect(map["media"], isA<List<dynamic>>());
      expect((map["media"] as List).first["id"], 7);
      expect(map["pagination"], isA<Map<String, dynamic>>());
    });

    test('fromJson({}) normalises media to [] and pagination to null', () {
      final data = Data.fromJson({});

      // Quirk: missing `media` becomes [], missing `pagination` stays null.
      expect(data.media, isEmpty);
      expect(data.pagination, isNull);
    });

    test('toJson serialises a null media field as an empty list', () {
      final map = Data().toJson();

      expect(map["media"], isEmpty);
      expect(map["pagination"], isNull);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Data.fromJson(fullJson["data"]);
      final copy = original.copyWith(pagination: Pagination(total: 99));

      expect(copy.pagination!.total, 99);
      expect(copy.media, same(original.media));
    });
  });

  group('Media', () {
    final mediaJson =
        (fullJson["data"]["media"] as List).first as Map<String, dynamic>;

    test('fromJson maps snake_case keys and parses the nested Sender', () {
      final m = Media.fromJson(mediaJson);

      expect(m.id, 7);
      expect(m.fileUrl, "https://cdn/m.jpg");
      expect(m.fileType, "image");
      expect(m.sentAt, "2026-01-01T00:00:00Z");
      expect(m.sender, isNotNull);
      expect(m.sender!.name, "Sam");
    });

    test('toJson emits snake_case keys and serialises the sender', () {
      final map = Media.fromJson(mediaJson).toJson();

      expect(map["id"], 7);
      expect(map["file_url"], "https://cdn/m.jpg");
      expect(map["file_type"], "image");
      expect(map["sent_at"], "2026-01-01T00:00:00Z");
      expect(map["sender"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Media.fromJson(mediaJson);
      final restored = Media.fromRawJson(original.toRawJson());

      expect(restored.id, 7);
      expect(restored.fileUrl, "https://cdn/m.jpg");
      expect(restored.sender!.id, 3);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Media.fromJson(mediaJson);
      final copy = original.copyWith(fileType: "video");

      expect(copy.fileType, "video");
      expect(copy.id, original.id);
      expect(copy.sender, same(original.sender));
    });

    test('fromJson({}) guards a missing sender to null', () {
      final m = Media.fromJson({});

      expect(m.sender, isNull);
      expect(m.id, isNull);
      expect(m.fileUrl, isNull);
      expect(m.fileType, isNull);
      expect(m.sentAt, isNull);
    });
  });

  group('Sender', () {
    final senderJson = <String, dynamic>{
      "id": 3,
      "name": "Sam",
      "avatar": "https://cdn/s.png",
    };

    test('fromJson parses every field', () {
      final s = Sender.fromJson(senderJson);

      expect(s.id, 3);
      expect(s.name, "Sam");
      expect(s.avatar, "https://cdn/s.png");
    });

    test('toJson emits all keys with their values', () {
      final map = Sender.fromJson(senderJson).toJson();

      expect(map["id"], 3);
      expect(map["name"], "Sam");
      expect(map["avatar"], "https://cdn/s.png");
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Sender.fromJson(senderJson);
      final restored = Sender.fromRawJson(original.toRawJson());

      expect(restored.id, 3);
      expect(restored.name, "Sam");
      expect(restored.avatar, "https://cdn/s.png");
    });

    test('copyWith overrides only the supplied field', () {
      final copy = Sender.fromJson(senderJson).copyWith(name: "Sammy");

      expect(copy.name, "Sammy");
      expect(copy.id, 3);
      expect(copy.avatar, "https://cdn/s.png");
    });

    test('fromJson({}) leaves every field null', () {
      final s = Sender.fromJson({});

      expect(s.id, isNull);
      expect(s.name, isNull);
      expect(s.avatar, isNull);
    });

    test('avatar tolerates a null dynamic value', () {
      // `avatar` is typed dynamic; a JSON null is preserved as-is.
      final s = Sender.fromJson({"id": 1, "name": "X", "avatar": null});

      expect(s.avatar, isNull);
      expect(s.toJson()["avatar"], isNull);
    });
  });

  group('Pagination', () {
    final pagJson = <String, dynamic>{
      "total": 80,
      "current_page": 3,
      "last_page": 8,
      "per_page": 10,
    };

    test('fromJson maps snake_case keys onto camelCase fields', () {
      final p = Pagination.fromJson(pagJson);

      expect(p.total, 80);
      expect(p.currentPage, 3);
      expect(p.lastPage, 8);
      expect(p.perPage, 10);
    });

    test('toJson emits snake_case keys', () {
      final map = Pagination.fromJson(pagJson).toJson();

      expect(map["total"], 80);
      expect(map["current_page"], 3);
      expect(map["last_page"], 8);
      expect(map["per_page"], 10);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Pagination.fromJson(pagJson);
      final restored = Pagination.fromRawJson(original.toRawJson());

      expect(restored.total, 80);
      expect(restored.currentPage, 3);
      expect(restored.lastPage, 8);
      expect(restored.perPage, 10);
    });

    test('copyWith overrides only the supplied field', () {
      final copy = Pagination.fromJson(pagJson).copyWith(lastPage: 9);

      expect(copy.lastPage, 9);
      expect(copy.total, 80);
      expect(copy.currentPage, 3);
    });

    test('fromJson({}) leaves every field null', () {
      final p = Pagination.fromJson({});

      expect(p.total, isNull);
      expect(p.currentPage, isNull);
      expect(p.lastPage, isNull);
      expect(p.perPage, isNull);
    });
  });
}
