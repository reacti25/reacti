import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for changing the signed-in user's password.
///
/// Implemented as a lazy singleton since it holds no per-call state.
/// (The class name retains the original `Chnage` spelling for compatibility.)
/// Not `final` so a test can supply a fake via `implements ChnagePasswordApi`.
class ChnagePasswordApi {
  /// The single shared instance, created lazily on first access.
  static final ChnagePasswordApi _singleton = ChnagePasswordApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  ChnagePasswordApi._internal();

  /// The shared [ChnagePasswordApi] instance.
  static ChnagePasswordApi get instance => _singleton;

  /// Submits a password change to the backend.
  ///
  /// [oldPass] is the current password, [newPass] the desired one and
  /// [confNewPass] its confirmation. Returns the decoded JSON body as a
  /// [Map] on HTTP 200, throws the default [DataSource] failure for any
  /// other status code, and rethrows transport-level errors.
  Future<Map> changePassword({
    required String oldPass,
    required String newPass,
    required String confNewPass,
  }) async {
    try {
      Map data = {
        'current_password': oldPass,
        'password': newPass,
        'password_confirmation': confNewPass,
      };
      Response response = await postHttp(EndPoints.changePassword(), data);
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
