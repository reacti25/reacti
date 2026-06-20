// Tests for the size/media-kind bucketing helpers and the failure-reason mapper.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_buckets.dart';

DioException _dio(DioExceptionType type, {int? status}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  response:
      status == null
          ? null
          : Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: status,
          ),
);

void main() {
  group('sizeBucket', () {
    test('maps bytes to the catalog buckets at the boundaries', () {
      expect(sizeBucket(0), 'xs');
      expect(sizeBucket(256 * 1024 - 1), 'xs');
      expect(sizeBucket(256 * 1024), 'sm');
      expect(sizeBucket(1024 * 1024 - 1), 'sm');
      expect(sizeBucket(1024 * 1024), 'md');
      expect(sizeBucket(5 * 1024 * 1024 - 1), 'md');
      expect(sizeBucket(5 * 1024 * 1024), 'lg');
      expect(sizeBucket(20 * 1024 * 1024 - 1), 'lg');
      expect(sizeBucket(20 * 1024 * 1024), 'xl');
    });
  });

  group('mediaKindFromPath', () {
    test('classifies images and videos by extension', () {
      expect(mediaKindFromPath('a/b/photo.JPG'), 'image');
      expect(mediaKindFromPath('reaction.mp4'), 'video');
      expect(mediaKindFromPath('clip.mov'), 'video');
    });

    test('returns null for unknown or extension-less paths', () {
      expect(mediaKindFromPath('file.txt'), isNull);
      expect(mediaKindFromPath('noextension'), isNull);
    });
  });

  group('failureReasonFromError', () {
    test('maps the dio timeout types to timeout', () {
      expect(
        failureReasonFromError(_dio(DioExceptionType.connectionTimeout)),
        'timeout',
      );
      expect(
        failureReasonFromError(_dio(DioExceptionType.sendTimeout)),
        'timeout',
      );
      expect(
        failureReasonFromError(_dio(DioExceptionType.receiveTimeout)),
        'timeout',
      );
    });

    test('maps a connection error to network', () {
      expect(
        failureReasonFromError(_dio(DioExceptionType.connectionError)),
        'network',
      );
    });

    test('maps bad responses to status buckets, 401 to unauthorized', () {
      expect(
        failureReasonFromError(_dio(DioExceptionType.badResponse, status: 401)),
        'unauthorized',
      );
      expect(
        failureReasonFromError(_dio(DioExceptionType.badResponse, status: 422)),
        'http_4xx',
      );
      expect(
        failureReasonFromError(_dio(DioExceptionType.badResponse, status: 503)),
        'http_5xx',
      );
    });

    test('a bad response with no status, or a non-dio error, is unknown', () {
      expect(
        failureReasonFromError(_dio(DioExceptionType.badResponse)),
        'unknown',
      );
      expect(failureReasonFromError(Exception('boom')), 'unknown');
      expect(failureReasonFromError(null), 'unknown');
    });
  });
}
