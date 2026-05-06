import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class SignUpApi {
  static final SignUpApi _singleton = SignUpApi._internal();
  SignUpApi._internal();
  static SignUpApi get instance => _singleton;

  Future<Map> signup({
    required String fName,
    required String lName,
    required String email,
    required String phone,
    required String password,
    required String confPassword,
  }) async {
    try {
      Map data = {
        "first_name": fName,
        "last_name": lName,
        "email": email,
        "phone": phone,
        "password": password,
        "password_confirmation": confPassword,
      };

      Response response = await postHttp(EndPoints.signup(), data);

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
