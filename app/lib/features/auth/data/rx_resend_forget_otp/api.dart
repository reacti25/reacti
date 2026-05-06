import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

final class ResendForgetOtpApi {
  static final ResendForgetOtpApi _singleton = ResendForgetOtpApi._internal();
  ResendForgetOtpApi._internal();
  static ResendForgetOtpApi get instance => _singleton;

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
