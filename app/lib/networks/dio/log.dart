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

/// Pretty-prints [data] as indented JSON for log output.
///
/// Accepts either a JSON [String] (decoded then re-encoded) or an already
/// decoded object. Falls back to `toString()` if [data] is not valid JSON.
String _prettyJson(dynamic data) {
  try {
    const encoder = JsonEncoder.withIndent('  ');
    if (data is String) {
      return encoder.convert(json.decode(data));
    }
    return encoder.convert(data);
  } catch (_) {
    return data.toString();
  }
}

/// Dio [Interceptor] that logs every request, response, and error.
///
/// Attached to the [DioSingleton] client for visibility during development.
/// On error it also routes the [DioException] through [ErrorHandler.handle] to
/// derive a user-facing [Failure].
final class Logger extends Interceptor {
  /// Logs the outgoing request (method, URL, headers, body) before it is sent,
  /// then forwards control via [super.onRequest].
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.i(
      '📤 REQUEST[${options.method}] => URL: ${options.baseUrl}${options.path}\n'
      '├── Headers: ${_prettyJson(options.headers)}\n'
      '├── ContentType: ${options.contentType}\n'
      '├── Data: ${_prettyJson(options.data)}\n'
      '└── Extra: ${options.extra}',
    );
    return super.onRequest(options, handler);
  }

  /// Logs the incoming [response] (status, headers, body) then forwards
  /// control via [super.onResponse].
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d(
      '📥 RESPONSE[${response.statusCode}] => URL: ${response.requestOptions.baseUrl}${response.requestOptions.path}\n'
      '├── Status Message: ${response.statusMessage}\n'
      '├── Headers: ${response.headers}\n'
      '└── Data:\n${_prettyJson(response.data)}',
    );
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
