// Tests for AnalyticsIdentity.hashUserId — the user-id pseudonymisation.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_identity.dart';

void main() {
  group('AnalyticsIdentity.hashUserId', () {
    test('is deterministic for the same input', () {
      expect(
        AnalyticsIdentity.hashUserId('42', salt: 's'),
        AnalyticsIdentity.hashUserId('42', salt: 's'),
      );
    });

    test('never returns the raw id and is a 64-char hex digest', () {
      final hash = AnalyticsIdentity.hashUserId('42');
      expect(hash, isNot('42'));
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('different salts produce different hashes', () {
      expect(
        AnalyticsIdentity.hashUserId('42', salt: 'a'),
        isNot(AnalyticsIdentity.hashUserId('42', salt: 'b')),
      );
    });

    test('empty id returns empty (anonymous user)', () {
      expect(AnalyticsIdentity.hashUserId(''), isEmpty);
      expect(AnalyticsIdentity.hashUserId('', salt: 's'), isEmpty);
    });
  });
}
