// Unit tests for the get_request_response.dart JSON DTOs.
//
// Pins the current parsing/serialisation behaviour of [GetRequestResponse]
// and its nested [Data], [Pagination], [Request] and [Person] classes:
// snake_case key mapping, round-trips, copyWith semantics, and the
// null/missing-field tolerances each factory bakes in.

import 'package:achiar_expert_app/features/friends/model/get_request_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fully populated decoded server envelope reused across the groups.
  final fullJson = <String, dynamic>{
    "success": true,
    "message": "ok",
    "code": 200,
    "data": {
      "requests": [
        {
          "id": 11,
          "person": {
            "id": 99,
            "first_name": "Alice",
            "last_name": "Adams",
            "username": "alice",
            "avatar": "https://cdn/a.png",
            "full_name": "Alice Adams",
          },
          "status": "pending",
          "sent_at": "2026-01-01T00:00:00Z",
          "accepted_at": null,
          "declined_at": null,
          "is_sent": true,
        },
      ],
      "pagination": {
        "total": 1,
        "current_page": 1,
        "last_page": 1,
        "per_page": 20,
      },
    },
  };

  group('GetRequestResponse', () {
    test('fromJson parses the envelope and nested Data payload', () {
      final res = GetRequestResponse.fromJson(fullJson);

      expect(res.success, isTrue);
      expect(res.message, "ok");
      expect(res.code, 200);
      expect(res.data, isNotNull);
      expect(res.data!.requests, hasLength(1));
      expect(res.data!.pagination!.total, 1);
    });

    test('toJson emits envelope keys and delegates to data.toJson', () {
      final res = GetRequestResponse.fromJson(fullJson);
      final map = res.toJson();

      expect(map["success"], isTrue);
      expect(map["message"], "ok");
      expect(map["code"], 200);
      expect(map["data"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = GetRequestResponse.fromJson(fullJson);
      final restored = GetRequestResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.code, original.code);
      expect(restored.data!.requests!.first.id, 11);
      expect(restored.data!.pagination!.perPage, 20);
    });

    test('copyWith overrides only the supplied field', () {
      final original = GetRequestResponse.fromJson(fullJson);
      final copy = original.copyWith(code: 404);

      expect(copy.code, 404);
      expect(copy.success, original.success);
      expect(copy.data, same(original.data));
    });

    test('fromJson({}) yields a null data and toJson emits null data', () {
      final res = GetRequestResponse.fromJson({});

      // Quirk: unlike list-bearing envelopes, a missing `data` stays null.
      expect(res.data, isNull);
      expect(res.toJson()["data"], isNull);
    });
  });

  group('Data', () {
    test('fromJson parses the requests list and pagination', () {
      final data = Data.fromJson(fullJson["data"]);

      expect(data.requests, hasLength(1));
      expect(data.requests!.first.status, "pending");
      expect(data.pagination!.currentPage, 1);
    });

    test('toJson serialises requests as a list and pagination as a map', () {
      final map = Data.fromJson(fullJson["data"]).toJson();

      expect(map["requests"], isA<List<dynamic>>());
      expect((map["requests"] as List).first["id"], 11);
      expect(map["pagination"], isA<Map<String, dynamic>>());
    });

    test('fromJson({}) normalises requests to [] and pagination to null', () {
      final data = Data.fromJson({});

      // Quirk: missing `requests` becomes [], missing `pagination` stays null.
      expect(data.requests, isEmpty);
      expect(data.pagination, isNull);
    });

    test('toJson serialises a null requests field as an empty list', () {
      final map = Data().toJson();

      expect(map["requests"], isEmpty);
      expect(map["pagination"], isNull);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Data.fromJson(fullJson["data"]);
      final copy = original.copyWith(pagination: Pagination(total: 9));

      expect(copy.pagination!.total, 9);
      expect(copy.requests, same(original.requests));
    });
  });

  group('Pagination', () {
    final pagJson = <String, dynamic>{
      "total": 50,
      "current_page": 2,
      "last_page": 5,
      "per_page": 10,
    };

    test('fromJson maps snake_case keys onto camelCase fields', () {
      final p = Pagination.fromJson(pagJson);

      expect(p.total, 50);
      expect(p.currentPage, 2);
      expect(p.lastPage, 5);
      expect(p.perPage, 10);
    });

    test('toJson emits snake_case keys', () {
      final map = Pagination.fromJson(pagJson).toJson();

      expect(map["total"], 50);
      expect(map["current_page"], 2);
      expect(map["last_page"], 5);
      expect(map["per_page"], 10);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Pagination.fromJson(pagJson);
      final restored = Pagination.fromRawJson(original.toRawJson());

      expect(restored.total, 50);
      expect(restored.currentPage, 2);
      expect(restored.lastPage, 5);
      expect(restored.perPage, 10);
    });

    test('copyWith overrides only the supplied field', () {
      final copy = Pagination.fromJson(pagJson).copyWith(currentPage: 3);

      expect(copy.currentPage, 3);
      expect(copy.total, 50);
      expect(copy.perPage, 10);
    });

    test('fromJson({}) leaves every field null', () {
      final p = Pagination.fromJson({});

      expect(p.total, isNull);
      expect(p.currentPage, isNull);
      expect(p.lastPage, isNull);
      expect(p.perPage, isNull);
    });
  });

  group('Request', () {
    final reqJson =
        (fullJson["data"]["requests"] as List).first as Map<String, dynamic>;

    test('fromJson maps snake_case keys and parses the nested Person', () {
      final r = Request.fromJson(reqJson);

      expect(r.id, 11);
      expect(r.status, "pending");
      expect(r.sentAt, "2026-01-01T00:00:00Z");
      expect(r.acceptedAt, isNull);
      expect(r.declinedAt, isNull);
      expect(r.isSent, isTrue);
      expect(r.person, isNotNull);
      expect(r.person!.username, "alice");
    });

    test('toJson emits snake_case keys and delegates to person.toJson', () {
      final map = Request.fromJson(reqJson).toJson();

      expect(map["id"], 11);
      expect(map["status"], "pending");
      expect(map["sent_at"], "2026-01-01T00:00:00Z");
      expect(map["accepted_at"], isNull);
      expect(map["declined_at"], isNull);
      expect(map["is_sent"], isTrue);
      expect(map["person"], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Request.fromJson(reqJson);
      final restored = Request.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.status, original.status);
      expect(restored.isSent, original.isSent);
      expect(restored.person!.fullName, original.person!.fullName);
    });

    test('copyWith overrides only the supplied field', () {
      final original = Request.fromJson(reqJson);
      final copy = original.copyWith(status: "accepted");

      expect(copy.status, "accepted");
      expect(copy.id, original.id);
      expect(copy.person, same(original.person));
    });

    test('fromJson({}) leaves person null and other fields null', () {
      final r = Request.fromJson({});

      // Quirk: a missing `person` is guarded to null (no empty object).
      expect(r.person, isNull);
      expect(r.id, isNull);
      expect(r.status, isNull);
      expect(r.isSent, isNull);
    });

    test('acceptedAt/declinedAt accept dynamic string values', () {
      // Typed dynamic — the API may send a timestamp string instead of null.
      final r = Request.fromJson({
        "accepted_at": "2026-02-02T00:00:00Z",
        "declined_at": "2026-03-03T00:00:00Z",
      });

      expect(r.acceptedAt, "2026-02-02T00:00:00Z");
      expect(r.declinedAt, "2026-03-03T00:00:00Z");
    });
  });

  group('Person', () {
    final personJson = <String, dynamic>{
      "id": 99,
      "first_name": "Alice",
      "last_name": "Adams",
      "username": "alice",
      "avatar": "https://cdn/a.png",
      "full_name": "Alice Adams",
    };

    test('fromJson maps snake_case keys onto camelCase fields', () {
      final p = Person.fromJson(personJson);

      expect(p.id, 99);
      expect(p.firstName, "Alice");
      expect(p.lastName, "Adams");
      expect(p.username, "alice");
      expect(p.avatar, "https://cdn/a.png");
      expect(p.fullName, "Alice Adams");
    });

    test('toJson emits snake_case keys', () {
      final map = Person.fromJson(personJson).toJson();

      expect(map["first_name"], "Alice");
      expect(map["last_name"], "Adams");
      expect(map["full_name"], "Alice Adams");
      expect(map["username"], "alice");
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Person.fromJson(personJson);
      final restored = Person.fromRawJson(original.toRawJson());

      expect(restored.id, 99);
      expect(restored.firstName, "Alice");
      expect(restored.fullName, "Alice Adams");
    });

    test('copyWith overrides only the supplied field', () {
      final copy = Person.fromJson(personJson).copyWith(firstName: "Anne");

      expect(copy.firstName, "Anne");
      expect(copy.lastName, "Adams");
      expect(copy.id, 99);
    });

    test('fromJson({}) leaves every field null', () {
      final p = Person.fromJson({});

      expect(p.id, isNull);
      expect(p.firstName, isNull);
      expect(p.lastName, isNull);
      expect(p.username, isNull);
      expect(p.avatar, isNull);
      expect(p.fullName, isNull);
    });
  });
}
