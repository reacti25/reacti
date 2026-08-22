// Unit tests for InviteService's pure helpers (Feature 5).

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/invite/data/invite_service.dart';

void main() {
  final service = InviteService();

  group('linkFor', () {
    test(
      'builds an /i/{code} link on the API host (not the dead reacti.app)',
      () {
        final link = service.linkFor('abc123');
        expect(link, endsWith('/i/abc123'));
        expect(link, isNot(contains('reacti.app')));
        expect(link, isNot(contains('/api')));
      },
    );
  });

  group('codeFromInput', () {
    test('extracts the code from a full share link', () {
      expect(service.codeFromInput('https://reacti.app/i/abc123'), 'abc123');
    });

    test('extracts from a bare host link', () {
      expect(service.codeFromInput('reacti.app/i/xyz789'), 'xyz789');
    });

    test('accepts a bare code', () {
      expect(service.codeFromInput('deadbeef01'), 'deadbeef01');
    });

    test('trims surrounding whitespace', () {
      expect(service.codeFromInput('  code42  '), 'code42');
    });

    test('returns null for empty or junk input', () {
      expect(service.codeFromInput(''), isNull);
      expect(service.codeFromInput('   '), isNull);
      expect(service.codeFromInput('not a code!'), isNull);
    });
  });
}
