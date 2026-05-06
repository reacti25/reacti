import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../../networks/dio/dio.dart';
import '../../../../../../networks/exception_handler/data_source.dart';

final class ForgetPassApi {
  static final ForgetPassApi _singleton = ForgetPassApi._internal();
  ForgetPassApi._internal();
  static ForgetPassApi get instance => _singleton;

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
