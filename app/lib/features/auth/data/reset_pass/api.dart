import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for the password-reset step of the forgot-password flow.
///
/// Wraps the `POST` call that commits a new password once the user has proven
/// ownership of the account via the OTP-issued reset token. Implemented as a
/// lazy singleton so callers share one instance.
/// Not `final` so a test can supply a fake via `implements ResetPasswordApi`.
class ResetPasswordApi {
  /// The single shared [ResetPasswordApi] instance.
  static final ResetPasswordApi _singleton = ResetPasswordApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  ResetPasswordApi._internal();

  /// The lazily-created shared [ResetPasswordApi] instance.
  static ResetPasswordApi get instance => _singleton;

  /// Submits a new password for the account identified by [email].
  ///
  /// [token] is the reset token issued after OTP verification, [password] is
  /// the new password and [confPass] its confirmation. Returns the decoded
  /// response map on HTTP 200. Throws the default [DataSource] failure for any
  /// other status code and rethrows transport errors.
  Future<Map> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confPass,
  }) async {
    try {
      Map data = {
        "email": email,
        "token": token,
        "password": password,
        "password_confirmation": confPass,
      };

      Response response = await postHttp(EndPoints.resetPassword(), data);

      if (response.statusCode == 200) {
        final data = json.decode(json.encode(response.data));
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
