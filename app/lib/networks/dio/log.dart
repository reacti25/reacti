import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as pkg_logger;

import '../exception_handler/data_source.dart';

final _logger = pkg_logger.Logger(
  printer: pkg_logger.PrettyPrinter(
    methodCount: 0,
    printEmojis: true,
    dateTimeFormat: pkg_logger.DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

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

final class Logger extends Interceptor {
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
