import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/exception_handler/data_source.dart';
import '../../model/login_response.dart';

/// HTTP data source for the email/password login step.
///
/// Wraps the `POST` call that authenticates a user and returns their session
/// token. Implemented as a lazy singleton so callers share one instance.
/// Not `final` so a test can supply a fake via `implements LoginApi`.
class LoginApi {
  /// The single shared [LoginApi] instance.
  static final LoginApi _singleton = LoginApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  LoginApi._internal();

  /// The lazily-created shared [LoginApi] instance.
  static LoginApi get instance => _singleton;

  /// Authenticates the user with [email] and [password].
  ///
  /// Returns the parsed [LoginResponse] (including the auth token) on HTTP 200.
  /// Throws the default [DataSource] failure for any other status code and
  /// rethrows transport errors.
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      Map data = {"email": email, "password": password};

      Response response = await postHttp(EndPoints.login(), data);

      if (response.statusCode == 200) {
        final data = LoginResponse.fromRawJson(json.encode(response.data));
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
