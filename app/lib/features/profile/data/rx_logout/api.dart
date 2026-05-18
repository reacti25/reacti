import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for logging the current user out of this device.
///
/// Implemented as a lazy singleton since it holds no per-call state.
/// Not `final` so a test can supply a fake via `implements LogoutApi`.
class LogoutApi {
  /// The single shared instance, created lazily on first access.
  static final LogoutApi _singleton = LogoutApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  LogoutApi._internal();

  /// The shared [LogoutApi] instance.
  static LogoutApi get instance => _singleton;

  /// Logs the current user out, scoped to this device.
  ///
  /// The device id is read from local storage so the backend can revoke the
  /// token bound to this device only. Returns the decoded JSON body as a
  /// [Map] on HTTP 200, throws the default [DataSource] failure for any
  /// other status code, and rethrows transport-level errors.
  Future<Map> userLogout() async {
    try {
      Map data = {'device_id': appData.read(kKeyDeviceID)};
      Response response = await postHttp(EndPoints.logout(), data);
      if (response.statusCode == 200) {
        final data = json.decode(json.encode(response.data));
        return data;
      } else {
        log('Error: ${response.statusCode}');
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (e) {
      rethrow;
    }
  }
}
