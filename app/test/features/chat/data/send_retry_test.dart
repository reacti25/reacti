// Unit tests for the bounded send retry (branch 2.4). The retry MUST be safe
// for the patented reaction upload: it may only retry transport errors that
// prove the request never reached the server, never anything that could have
// been persisted (which would risk a duplicate reaction).

import 'package:dio/dio.dart';
import 'package:reacti_app/features/chat/data/send_retry.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/send'), type: type);

void main() {
  group('isRetriableSendError', () {
    test('retries only pre-delivery transport errors', () {
      expect(
        isRetriableSendError(_err(DioExceptionType.connectionError)),
        isTrue,
      );
      expect(
        isRetriableSendError(_err(DioExceptionType.connectionTimeout)),
        isTrue,
      );
    });

    test('never retries anything that may have reached the server', () {
      // receiveTimeout / badResponse / sendTimeout could have been persisted —
      // retrying risks a duplicate reaction. cancel + non-Dio errors too.
      for (final t in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.badResponse,
        DioExceptionType.sendTimeout,
        DioExceptionType.cancel,
      ]) {
        expect(isRetriableSendError(_err(t)), isFalse, reason: '$t');
      }
      expect(isRetriableSendError(Exception('nope')), isFalse);
    });
  });

  group('withSendRetry', () {
    Future<void> noWait(int _) async {}

    test('returns immediately on success (one attempt)', () async {
      var calls = 0;
      final result = await withSendRetry(() async {
        calls++;
        return 'ok';
      }, delay: noWait);
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('retries a pre-delivery error then succeeds', () async {
      var calls = 0;
      final result = await withSendRetry(() async {
        calls++;
        if (calls < 2) throw _err(DioExceptionType.connectionError);
        return 'ok';
      }, delay: noWait);
      expect(result, 'ok');
      expect(calls, 2);
    });

    test('does NOT retry a server-reached error — rethrows at once', () async {
      var calls = 0;
      await expectLater(
        withSendRetry(() async {
          calls++;
          throw _err(DioExceptionType.badResponse);
        }, delay: noWait),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1, reason: 'no retry for a possibly-persisted send');
    });

    test(
      'gives up after maxAttempts on a persistent retriable error',
      () async {
        var calls = 0;
        await expectLater(
          withSendRetry(
            () async {
              calls++;
              throw _err(DioExceptionType.connectionError);
            },
            maxAttempts: 3,
            delay: noWait,
          ),
          throwsA(isA<DioException>()),
        );
        expect(calls, 3);
      },
    );
  });
}
