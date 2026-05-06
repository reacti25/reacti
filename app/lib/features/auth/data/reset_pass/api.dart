import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

final class ResetPasswordApi {
  static final ResetPasswordApi _singleton = ResetPasswordApi._internal();
  ResetPasswordApi._internal();
  static ResetPasswordApi get instance => _singleton;

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
