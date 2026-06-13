import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/consent/data/consent_service.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../../support/test_storage.dart';

/// Authed-POST stub returning a successful consent response with a known
/// server timestamp.
Future<Response> _okPoster(String path) async => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: {
    'success': true,
    'data': {'recording_consent_at': '2026-06-13T00:00:00.000Z'},
    'code': 200,
  },
);

/// Authed-POST stub returning a non-success envelope.
Future<Response> _failPoster(String path) async => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: {'success': false, 'message': 'nope', 'code': 400},
);

/// Authed-POST stub simulating a transport failure.
Future<Response> _throwingPoster(String path) async =>
    throw DioException(requestOptions: RequestOptions(path: path));

void main() {
  // Use the test-container GetStorage that initTestGetStorage registers in the
  // locator (the default container is not initialised under `flutter test`).
  late GetStorage storage;

  setUp(() async {
    await initTestGetStorage();
    storage = locator.get<GetStorage>();
    storage.remove(kKeyRecordingConsentAt);
  });

  ConsentService makeService(ConsentPoster poster) =>
      ConsentService(storage: storage, poster: poster);

  test('hasConsented is false when nothing is stored', () {
    expect(makeService(_okPoster).hasConsented, isFalse);
  });

  test(
    'grantConsent records consent on the server and mirrors it locally',
    () async {
      final service = makeService(_okPoster);

      final result = await service.grantConsent();

      expect(result, isTrue);
      expect(service.hasConsented, isTrue);
      expect(storage.read(kKeyRecordingConsentAt), '2026-06-13T00:00:00.000Z');
    },
  );

  test(
    'grantConsent returns false and leaves the mirror untouched on a non-success response',
    () async {
      final service = makeService(_failPoster);

      expect(await service.grantConsent(), isFalse);
      expect(service.hasConsented, isFalse);
    },
  );

  test('grantConsent returns false on a transport error', () async {
    final service = makeService(_throwingPoster);

    expect(await service.grantConsent(), isFalse);
    expect(service.hasConsented, isFalse);
  });

  test('revokeConsent clears the local mirror', () {
    storage.write(kKeyRecordingConsentAt, '2026-06-13T00:00:00.000Z');
    final service = makeService(_okPoster);
    expect(service.hasConsented, isTrue);

    service.revokeConsent();

    expect(service.hasConsented, isFalse);
  });

  test(
    'syncFromServer sets the mirror from a non-null value and clears it on null',
    () {
      final service = makeService(_okPoster);

      service.syncFromServer('2026-06-13T00:00:00.000Z');
      expect(service.hasConsented, isTrue);

      service.syncFromServer(null);
      expect(service.hasConsented, isFalse);
    },
  );
}
