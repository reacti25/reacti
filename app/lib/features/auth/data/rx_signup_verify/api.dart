import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/exception_handler/data_source.dart';
import '../../model/login_response.dart';

/// HTTP data source for confirming the signup verification OTP.
///
/// Wraps the `POST` call that verifies the OTP emailed after registration; on
/// success the backend activates the account and returns a session token.
/// Implemented as a lazy singleton so callers share one instance.
/// Not `final` so a test can supply a fake via `implements SignUpVerifyApi`.
class SignUpVerifyApi {
  /// The single shared [SignUpVerifyApi] instance.
  static final SignUpVerifyApi _singleton = SignUpVerifyApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  SignUpVerifyApi._internal();

  /// The lazily-created shared [SignUpVerifyApi] instance.
  static SignUpVerifyApi get instance => _singleton;

  /// Verifies the signup [otp] for the account identified by [email].
  ///
  /// Returns the parsed [LoginResponse] (including the auth token) on HTTP 200.
  /// Throws the default [DataSource] failure for any other status code and
  /// rethrows transport errors.
  Future<LoginResponse> verifySignupOtp({
    required String otp,
    required String email,
  }) async {
    try {
      Map data = {"email": email, "otp": otp};

      Response response = await postHttp(EndPoints.verifySignupOtp(), data);

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
