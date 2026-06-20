// Coarse bucketing helpers so analytics carries size/kind metadata without ever
// emitting an exact byte count (which could fingerprint a specific file).

import 'package:dio/dio.dart';

/// Maps a payload size in [bytes] to the catalog `size_bucket` enum.
///
/// `xs` (<256 KB), `sm` (<1 MB), `md` (<5 MB), `lg` (<20 MB), `xl` (≥20 MB).
String sizeBucket(int bytes) {
  if (bytes < 256 * 1024) return 'xs';
  if (bytes < 1024 * 1024) return 'sm';
  if (bytes < 5 * 1024 * 1024) return 'md';
  if (bytes < 20 * 1024 * 1024) return 'lg';
  return 'xl';
}

/// Maps a file [path]'s extension to the catalog `media_kind` enum
/// (`image` | `video`), or null when it is neither.
String? mediaKindFromPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = path.substring(dot + 1).toLowerCase();
  const video = {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'm4v', 'mpeg'};
  const image = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif'};
  if (video.contains(ext)) return 'video';
  if (image.contains(ext)) return 'image';
  return null;
}

/// Maps a network [error] to the catalog `failure_reason` enum so failed
/// requests are diagnosable without leaking response bodies:
/// `unauthorized` (HTTP 401) | `http_4xx` | `http_5xx` | `timeout` | `network`
/// | `unknown`. Shared by mark-viewed, message-send and reaction-send
/// instrumentation. A non-[DioException] (or anything unrecognised) is
/// `unknown`.
String failureReasonFromError(Object? error) {
  if (error is! DioException) return 'unknown';

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'timeout';
    case DioExceptionType.connectionError:
      return 'network';
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401) return 'unauthorized';
      if (status >= 400 && status < 500) return 'http_4xx';
      if (status >= 500) return 'http_5xx';
      return 'unknown';
    default:
      return 'unknown';
  }
}
