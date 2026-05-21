// Unit tests for the redactSensitive helper used by the Dio Logger
// interceptor. The interceptor itself is gated on kDebugMode in
// production, but redaction is defence-in-depth: bearer tokens, OTPs,
// and passwords should never appear in any log output.

import 'package:reacti_app/networks/dio/log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactSensitive', () {
    test('redacts an Authorization header (case-insensitive)', () {
      final result = redactSensitive({
        'Authorization': 'Bearer abc.def.ghi',
        'Accept': 'application/json',
      });

      expect(result['Authorization'], '<redacted>');
      expect(result['Accept'], 'application/json');
    });

    test('redacts authorization with lowercase key too', () {
      final result = redactSensitive({'authorization': 'Bearer xyz'});
      expect(result['authorization'], '<redacted>');
    });

    test('redacts password, otp, token in a request body', () {
      final result = redactSensitive({
        'email': 'a@b.com',
        'password': 'hunter2',
        'otp': '0421',
        'token': 'reset-token-here',
      });

      expect(result['email'], 'a@b.com');
      expect(result['password'], '<redacted>');
      expect(result['otp'], '<redacted>');
      expect(result['token'], '<redacted>');
    });

    test('walks into nested maps and lists', () {
      final result = redactSensitive({
        'data': {
          'user': {'email': 'a@b.com', 'access_token': 'jwt-here'},
          'logs': [
            {'msg': 'ok'},
            {'msg': 'failed', 'otp': '1234'},
          ],
        },
      });

      expect(result['data']['user']['email'], 'a@b.com');
      expect(result['data']['user']['access_token'], '<redacted>');
      expect(result['data']['logs'][1]['otp'], '<redacted>');
      expect(result['data']['logs'][0]['msg'], 'ok');
    });

    test('leaves scalars and non-collection types alone', () {
      expect(redactSensitive('hello'), 'hello');
      expect(redactSensitive(42), 42);
      expect(redactSensitive(null), isNull);
    });
  });
}
