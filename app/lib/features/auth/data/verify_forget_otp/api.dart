import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for confirming the forgot-password OTP.
///
/// Wraps the `POST` call that verifies the OTP emailed during the
/// forgot-password flow; on success the backend returns a reset token that
/// authorizes the subsequent password change. Implemented as a lazy singleton
/// so callers share one instance.
/// Not `final` so a test can supply a fake via `implements VerifyForgetPassApi`.
class VerifyForgetPassApi {
  /// The single shared [VerifyForgetPassApi] instance.
  static final VerifyForgetPassApi _singleton = VerifyForgetPassApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  VerifyForgetPassApi._internal();

  /// The lazily-created shared [VerifyForgetPassApi] instance.
  static VerifyForgetPassApi get instance => _singleton;

  /// Verifies the forgot-password [otp] for the account identified by [email].
  ///
  /// Returns the decoded response map (which carries the reset `token`) on
  /// HTTP 200/201. Throws the default [DataSource] failure for any other
  /// status code and rethrows transport errors.
  Future<Map> verifyForgetPass({
    required String email,
    required String otp,
  }) async {
    try {
      Map data = {"email": email, "otp": otp};

      Response response = await postHttp(EndPoints.verifyForgetPass(), data);

      if (response.statusCode == 200 || response.statusCode == 201) {
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
