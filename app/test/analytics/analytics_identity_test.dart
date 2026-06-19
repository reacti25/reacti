// Tests for AnalyticsIdentity.hashUserId — the user-id pseudonymisation.
//
// Pins the hardening: the digest is SALTED (so a plain SHA-256 of a sequential
// id can't be brute-forced), and with no salt configured it returns empty
// rather than ever producing a reversible unsalted hash.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_identity.dart';

void main() {
  group('AnalyticsIdentity.hashUserId', () {
    test('is deterministic for the same id + salt', () {
      expect(
        AnalyticsIdentity.hashUserId('42', salt: 's'),
        AnalyticsIdentity.hashUserId('42', salt: 's'),
      );
    });

    test('never returns the raw id and is a 64-char hex digest', () {
      final hash = AnalyticsIdentity.hashUserId('42', salt: 'secret');
      expect(hash, isNot('42'));
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('is SALTED — differs from the plain (unsalted) SHA-256 of the id', () {
      // The exact attack we are defending against: hashing the raw id alone.
      final plain = sha256.convert(utf8.encode('42')).toString();
      expect(AnalyticsIdentity.hashUserId('42', salt: 'secret'), isNot(plain));
    });

    test('different salts produce different hashes for the same id', () {
      expect(
        AnalyticsIdentity.hashUserId('42', salt: 'a'),
        isNot(AnalyticsIdentity.hashUserId('42', salt: 'b')),
      );
    });

    test('no salt → empty (never a reversible unsalted hash)', () {
      expect(AnalyticsIdentity.hashUserId('42', salt: ''), isEmpty);
    });

    test('empty id → empty (anonymous user)', () {
      expect(AnalyticsIdentity.hashUserId('', salt: 'secret'), isEmpty);
    });
  });
}
