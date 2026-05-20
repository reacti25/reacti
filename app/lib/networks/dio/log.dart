import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as pkg_logger;

import '../exception_handler/data_source.dart';

/// Shared `logger` package instance used to print formatted network logs.
///
/// Configured with no method-call frames and emoji output for readability.
final _logger = pkg_logger.Logger(
  printer: pkg_logger.PrettyPrinter(
    methodCount: 0,
    printEmojis: true,
    dateTimeFormat: pkg_logger.DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Keys whose values are replaced with `<redacted>` before logging.
///
/// Comparison is case-insensitive — matches `Authorization`/`authorization`,
/// `OTP`/`otp`, etc. Exposed for testing.
const Set<String> redactedKeys = {
  'authorization',
  'password',
  'password_confirmation',
  'otp',
  'token',
  'access_token',
  'refresh_token',
};

/// Returns a deep copy of [data] with values under [redactedKeys] replaced
/// by `<redacted>`.
///
/// Walks `Map`s and `List`s recursively. Non-collection values are returned
/// unchanged. The check is case-insensitive on map keys.
dynamic redactSensitive(dynamic data) {
  if (data is Map) {
    return data.map((k, v) {
      if (redactedKeys.contains(k.toString().toLowerCase())) {
        return MapEntry(k, '<redacted>');
      }
      return MapEntry(k, redactSensitive(v));
    });
  }
  if (data is List) {
    return data.map(redactSensitive).toList();
  }
  return data;
}

/// Pretty-prints [data] as indented JSON for log output, with sensitive
/// keys ([redactedKeys]) replaced before serialisation.
///
/// Accepts either a JSON [String] (decoded then re-encoded) or an already
/// decoded object. Falls back to `toString()` if [data] is not valid JSON.
String _prettyJson(dynamic data) {
  try {
    const encoder = JsonEncoder.withIndent('  ');
    if (data is String) {
      return encoder.convert(redactSensitive(json.decode(data)));
    }
    return encoder.convert(redactSensitive(data));
  } catch (_) {
    return data.toString();
  }
}

/// Dio [Interceptor] that logs every request, response, and error.
///
/// All three branches are gated on [kDebugMode] — release builds emit
/// nothing — and request/response payloads are run through
/// [redactSensitive] so bearer tokens, OTPs and passwords do not land in
/// device logs even in debug. On error the [DioException] is still
/// routed through [ErrorHandler.handle] to derive a user-facing
/// [Failure]; the interceptor does not swallow the error.
final class Logger extends Interceptor {
  /// Logs the outgoing request (method, URL, redacted headers and body)
  /// before it is sent, then forwards control via [super.onRequest].
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.i(
        '📤 REQUEST[${options.method}] => URL: ${options.baseUrl}${options.path}\n'
        '├── Headers: ${_prettyJson(options.headers)}\n'
        '├── ContentType: ${options.contentType}\n'
        '├── Data: ${_prettyJson(options.data)}\n'
        '└── Extra: ${options.extra}',
      );
    }
    return super.onRequest(options, handler);
  }

  /// Logs the incoming [response] (status, headers, redacted body) then
  /// forwards control via [super.onResponse].
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.d(
        '📥 RESPONSE[${response.statusCode}] => URL: ${response.requestOptions.baseUrl}${response.requestOptions.path}\n'
        '├── Status Message: ${response.statusMessage}\n'
        '├── Headers: ${response.headers}\n'
        '└── Data:\n${_prettyJson(response.data)}',
      );
    }
    return super.onResponse(response, handler);
  }

  /// Logs the failed request (in debug builds only) and maps [err] to a
  /// [Failure] via [ErrorHandler.handle], then forwards control via
  /// [super.onError]. The interceptor does not swallow the error.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.e(
        '❌ ERROR[${err.response?.statusCode}] => URL: ${err.requestOptions.baseUrl}${err.requestOptions.path}\n'
        '├── Message: ${err.message}\n'
        '├── Type: ${err.type}\n'
        '├── Error: ${err.error}\n'
        '└── Response: ${_prettyJson(err.response?.data)}',
      );
    }
    ErrorHandler.handle(err).failure;
    return super.onError(err, handler);
  }
}
