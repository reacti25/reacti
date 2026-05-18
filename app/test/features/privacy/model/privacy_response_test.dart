// Unit tests for the Privacy Policy response models.
//
// Pins the JSON contract of `PrivacyResponse` and its nested `Data` page
// record: field decoding, snake_case JSON keys, raw-JSON round-trips,
// `copyWith` overrides, and null/missing-key tolerance.

import 'dart:convert';

import 'package:achiar_expert_app/features/privacy/model/privacy_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivacyResponse', () {
    test('fromJson decodes every field including the nested Data payload', () {
      final response = PrivacyResponse.fromJson({
        "status": true,
        "message": "OK",
        "data": {
          "id": 7,
          "page_title": "Privacy Policy",
          "page_slug": "privacy-policy",
          "page_content": "<p>policy</p>",
          "status": "active",
          "deleted_at": null,
        },
      });

      expect(response.status, isTrue);
      expect(response.message, 'OK');
      expect(response.data, isNotNull);
      expect(response.data!.id, 7);
      expect(response.data!.pageTitle, 'Privacy Policy');
      expect(response.data!.pageSlug, 'privacy-policy');
      expect(response.data!.pageContent, '<p>policy</p>');
      expect(response.data!.status, 'active');
      expect(response.data!.deletedAt, isNull);
    });

    test('fromJson keeps data null when the key is absent or null', () {
      expect(PrivacyResponse.fromJson({}).data, isNull);
      expect(PrivacyResponse.fromJson({"data": null}).data, isNull);
    });

    test('fromJson tolerates missing status and message keys', () {
      final response = PrivacyResponse.fromJson({});

      expect(response.status, isNull);
      expect(response.message, isNull);
      expect(response.data, isNull);
    });

    test('toJson emits the wrapper keys and the nested data map', () {
      final response = PrivacyResponse(
        status: false,
        message: 'fail',
        data: Data(id: 1, pageTitle: 'T'),
      );

      final map = response.toJson();

      expect(map.keys, containsAll(['status', 'message', 'data']));
      expect(map['status'], isFalse);
      expect(map['message'], 'fail');
      expect(map['data'], isA<Map<String, dynamic>>());
      expect((map['data'] as Map)['id'], 1);
      expect((map['data'] as Map)['page_title'], 'T');
    });

    test('toJson emits data as null when there is no payload', () {
      final map = PrivacyResponse(status: true).toJson();

      expect(map['data'], isNull);
    });

    test('round-trips through raw JSON preserving key fields', () {
      final original = PrivacyResponse(
        status: true,
        message: 'OK',
        data: Data(
          id: 9,
          pageTitle: 'Privacy Policy',
          pageSlug: 'privacy-policy',
          pageContent: '<h1>Hello</h1>',
          status: 'active',
          deletedAt: null,
        ),
      );

      final restored = PrivacyResponse.fromRawJson(original.toRawJson());

      expect(restored.status, original.status);
      expect(restored.message, original.message);
      expect(restored.data!.id, original.data!.id);
      expect(restored.data!.pageTitle, original.data!.pageTitle);
      expect(restored.data!.pageSlug, original.data!.pageSlug);
      expect(restored.data!.pageContent, original.data!.pageContent);
      expect(restored.data!.status, original.data!.status);
      expect(restored.data!.deletedAt, original.data!.deletedAt);
    });

    test('toRawJson produces a string that decodes to the toJson map', () {
      final response = PrivacyResponse(status: true, message: 'OK');

      expect(json.decode(response.toRawJson()), response.toJson());
    });

    test('copyWith overrides only the named field', () {
      final original = PrivacyResponse(
        status: true,
        message: 'original',
        data: Data(id: 1),
      );

      final copy = original.copyWith(message: 'changed');

      expect(copy.message, 'changed');
      expect(copy.status, original.status);
      expect(copy.data, same(original.data));
    });

    test('copyWith with no arguments keeps every field', () {
      final original = PrivacyResponse(
        status: false,
        message: 'm',
        data: Data(id: 2),
      );

      final copy = original.copyWith();

      expect(copy.status, original.status);
      expect(copy.message, original.message);
      expect(copy.data, same(original.data));
    });
  });

  group('Data (privacy page)', () {
    test('fromJson maps snake_case keys onto camelCase fields', () {
      final data = Data.fromJson({
        "id": 12,
        "page_title": "Terms",
        "page_slug": "terms",
        "page_content": "<p>body</p>",
        "status": "draft",
        "deleted_at": "2026-01-01T00:00:00Z",
      });

      expect(data.id, 12);
      expect(data.pageTitle, 'Terms');
      expect(data.pageSlug, 'terms');
      expect(data.pageContent, '<p>body</p>');
      expect(data.status, 'draft');
      expect(data.deletedAt, '2026-01-01T00:00:00Z');
    });

    test('fromJson leaves every field null when keys are missing', () {
      final data = Data.fromJson({});

      expect(data.id, isNull);
      expect(data.pageTitle, isNull);
      expect(data.pageSlug, isNull);
      expect(data.pageContent, isNull);
      expect(data.status, isNull);
      expect(data.deletedAt, isNull);
    });

    test('toJson emits the snake_case JSON keys', () {
      final map = Data(
        id: 3,
        pageTitle: 'Privacy',
        pageSlug: 'privacy',
        pageContent: '<p>c</p>',
        status: 'active',
        deletedAt: null,
      ).toJson();

      expect(map['id'], 3);
      expect(map['page_title'], 'Privacy');
      expect(map['page_slug'], 'privacy');
      expect(map['page_content'], '<p>c</p>');
      expect(map['status'], 'active');
      expect(map['deleted_at'], isNull);
      expect(map.keys, containsAll([
        'id',
        'page_title',
        'page_slug',
        'page_content',
        'status',
        'deleted_at',
      ]));
    });

    test('round-trips through raw JSON preserving fields', () {
      final original = Data(
        id: 5,
        pageTitle: 'P',
        pageSlug: 's',
        pageContent: '<b>x</b>',
        status: 'active',
        deletedAt: null,
      );

      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.pageTitle, original.pageTitle);
      expect(restored.pageSlug, original.pageSlug);
      expect(restored.pageContent, original.pageContent);
      expect(restored.status, original.status);
      expect(restored.deletedAt, original.deletedAt);
    });

    test('copyWith overrides only the named field', () {
      final original = Data(id: 1, pageTitle: 'T', status: 'active');

      final copy = original.copyWith(status: 'inactive');

      expect(copy.status, 'inactive');
      expect(copy.id, original.id);
      expect(copy.pageTitle, original.pageTitle);
    });
  });
}
