// Unit tests for the pure validation helper kept in
// lib/helpers/helpers_method.dart (emailRegex). setInitValue (storage + device
// info) and rotation (SystemChrome) are platform/UI bound and out of scope for
// unit tests. The unused date/time formatters were removed (ponytail Tier-1).

import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emailRegex', () {
    test('accepts well-formed addresses', () {
      expect(emailRegex.hasMatch('alice@example.com'), isTrue);
      expect(emailRegex.hasMatch('a.b+c@sub.example.co'), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(emailRegex.hasMatch('not-an-email'), isFalse);
      expect(emailRegex.hasMatch('missing@domain'), isFalse);
      expect(emailRegex.hasMatch('@example.com'), isFalse);
    });
  });
}
