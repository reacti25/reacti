import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for initiating the forgot-password flow.
///
/// Wraps the `POST` call that asks the backend to send a password-reset OTP to
/// a user's email. Implemented as a lazy singleton so callers share one
/// instance.
final class ForgetPassApi {
  /// The single shared [ForgetPassApi] instance.
  static final ForgetPassApi _singleton = ForgetPassApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  ForgetPassApi._internal();

  /// The lazily-created shared [ForgetPassApi] instance.
  static ForgetPassApi get instance => _singleton;

  /// Requests a password-reset OTP for the account identified by [email].
  ///
  /// Returns the decoded response map on HTTP 200/201. Throws the default
  /// [DataSource] failure for any other status code and rethrows transport
  /// errors.
  Future<Map> forgetPassword({required String email}) async {
    try {
      Map data = {"email": email};

      Response response = await postHttp(EndPoints.forgetPass(), data);

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
