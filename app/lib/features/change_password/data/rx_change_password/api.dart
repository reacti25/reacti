import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class ChnagePasswordApi {
  static final ChnagePasswordApi _singleton = ChnagePasswordApi._internal();
  ChnagePasswordApi._internal();

  static ChnagePasswordApi get instance => _singleton;

  Future<Map> changePassword({
    required String oldPass,
    required String newPass,
    required String confNewPass,
  }) async {
    try {
      Map data = {
        'current_password': oldPass,
        'password': newPass,
        'password_confirmation': confNewPass,
      };
      Response response = await postHttp(EndPoints.changePassword(), data);
      if (response.statusCode == 200) {
        final data = json.decode(json.encode(response.data));
        return data;
      } else {
        log('Error: ${response.statusCode}');
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (e) {
      rethrow;
    }
  }
}
