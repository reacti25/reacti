// Unit tests for the login_response.dart JSON DTOs.
//
// LoginResponse is the envelope returned by the login and signup-OTP
// verification endpoints; its nested Data holds the authenticated user
// profile and session token. These are plain decoded-map DTOs, so the
// tests below are pure and hermetic: they pin fromJson / toJson key
// mapping (snake_case JSON <-> camelCase Dart), round-trip stability,
// copyWith, and null/missing-key tolerance exactly as the code dictates.

import 'package:reacti_app/features/auth/model/login_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Data', () {
    // A representative, fully-populated decoded JSON map for the user payload.
    final dataMap = <String, dynamic>{
      'id': 42,
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'username': 'ada',
      'email': 'ada@example.com',
      'role': 'user',
      'avatar': 'https://cdn.example.com/ada.png',
      'token': 'tok_abc123',
      'last_activity_at': '2026-05-16T08:30:00.000Z',
    };

    test('fromJson parses every field including the DateTime', () {
      final data = Data.fromJson(dataMap);

      expect(data.id, 42);
      expect(data.firstName, 'Ada');
      expect(data.lastName, 'Lovelace');
      expect(data.username, 'ada');
      expect(data.email, 'ada@example.com');
      expect(data.role, 'user');
      expect(data.avatar, 'https://cdn.example.com/ada.png');
      expect(data.token, 'tok_abc123');
      expect(data.lastActivityAt, DateTime.parse('2026-05-16T08:30:00.000Z'));
    });

    test('toJson emits snake_case keys and ISO-8601 timestamp', () {
      final data = Data.fromJson(dataMap);
      final json = data.toJson();

      expect(json['id'], 42);
      expect(json['first_name'], 'Ada');
      expect(json['last_name'], 'Lovelace');
      expect(json['username'], 'ada');
      expect(json['email'], 'ada@example.com');
      expect(json['role'], 'user');
      expect(json['avatar'], 'https://cdn.example.com/ada.png');
      expect(json['token'], 'tok_abc123');
      // toIso8601String of a parsed UTC timestamp keeps the Z suffix.
      expect(json['last_activity_at'], '2026-05-16T08:30:00.000Z');
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Data.fromJson(dataMap);
      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.token, original.token);
      expect(restored.lastActivityAt, original.lastActivityAt);
    });

    test('copyWith overrides one field and leaves the rest intact', () {
      final original = Data.fromJson(dataMap);
      final copy = original.copyWith(token: 'tok_new');

      expect(copy.token, 'tok_new');
      // Untouched fields are preserved.
      expect(copy.id, 42);
      expect(copy.email, 'ada@example.com');
      expect(copy.lastActivityAt, original.lastActivityAt);
    });

    test('fromJson({}) tolerates all-missing keys; DateTime stays null', () {
      final data = Data.fromJson(<String, dynamic>{});

      expect(data.id, isNull);
      expect(data.firstName, isNull);
      expect(data.username, isNull);
      expect(data.token, isNull);
      // Guarded: missing last_activity_at must not call DateTime.parse.
      expect(data.lastActivityAt, isNull);
    });
  });

  group('LoginResponse', () {
    // A representative envelope wrapping a populated Data payload.
    final responseMap = <String, dynamic>{
      'success': true,
      'message': 'Login successful',
      'code': 200,
      'data': <String, dynamic>{
        'id': 7,
        'first_name': 'Grace',
        'last_name': 'Hopper',
        'username': 'grace',
        'email': 'grace@example.com',
        'role': 'admin',
        'avatar': null,
        'token': 'tok_grace',
        'last_activity_at': '2026-01-02T03:04:05.000Z',
      },
    };

    test('fromJson parses the envelope and nested Data', () {
      final response = LoginResponse.fromJson(responseMap);

      expect(response.success, isTrue);
      expect(response.message, 'Login successful');
      expect(response.code, 200);
      expect(response.data, isA<Data>());
      expect(response.data!.id, 7);
      expect(response.data!.token, 'tok_grace');
      expect(response.data!.avatar, isNull);
    });

    test('toJson emits the envelope keys and serialized nested data', () {
      final response = LoginResponse.fromJson(responseMap);
      final json = response.toJson();

      expect(json['success'], true);
      expect(json['message'], 'Login successful');
      expect(json['code'], 200);
      expect(json['data'], isA<Map<String, dynamic>>());
      expect((json['data'] as Map)['first_name'], 'Grace');
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = LoginResponse.fromJson(responseMap);
      final restored = LoginResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.token, original.data!.token);
    });

    test('copyWith overrides one field and leaves the rest intact', () {
      final original = LoginResponse.fromJson(responseMap);
      final copy = original.copyWith(success: false);

      expect(copy.success, isFalse);
      // Untouched fields, including the nested Data instance, are preserved.
      expect(copy.message, 'Login successful');
      expect(copy.code, 200);
      expect(copy.data, same(original.data));
    });

    test('fromJson guards a null data with a null nested object', () {
      final response = LoginResponse.fromJson(<String, dynamic>{
        'success': false,
        'message': 'Invalid credentials',
        'code': 401,
        'data': null,
      });

      expect(response.success, isFalse);
      expect(response.message, 'Invalid credentials');
      expect(response.code, 401);
      // The `data == null ? null : Data.fromJson(...)` guard is exercised.
      expect(response.data, isNull);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final response = LoginResponse.fromJson(<String, dynamic>{});

      expect(response.success, isNull);
      expect(response.message, isNull);
      expect(response.code, isNull);
      expect(response.data, isNull);
    });

    test('toJson of a response with null data emits data: null', () {
      final json = LoginResponse(success: false, code: 401).toJson();

      expect(json.containsKey('data'), isTrue);
      expect(json['data'], isNull);
    });
  });
}
