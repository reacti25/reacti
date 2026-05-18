import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for re-sending the forgot-password OTP.
///
/// Wraps the `POST` call invoked when a user's reset OTP has expired and they
/// request a fresh code. Implemented as a lazy singleton so callers share one
/// instance.
/// Not `final` so a test can supply a fake via `implements ResendForgetOtpApi`.
class ResendForgetOtpApi {
  /// The single shared [ResendForgetOtpApi] instance.
  static final ResendForgetOtpApi _singleton = ResendForgetOtpApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  ResendForgetOtpApi._internal();

  /// The lazily-created shared [ResendForgetOtpApi] instance.
  static ResendForgetOtpApi get instance => _singleton;

  /// Requests a new forgot-password OTP for the account identified by [email].
  ///
  /// Returns the decoded response map on HTTP 200/201. Throws the default
  /// [DataSource] failure for any other status code and rethrows transport
  /// errors.
  Future<Map> resendForgetOtp({required String email}) async {
    try {
      Map data = {"email": email};

      Response response = await postHttp(EndPoints.resendForgetOtp(), data);

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
