import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class LogoutApi {
  static final LogoutApi _singleton = LogoutApi._internal();
  LogoutApi._internal();

  static LogoutApi get instance => _singleton;

  Future<Map> userLogout() async {
    try {
      Map data = {'device_id': appData.read(kKeyDeviceID)};
      Response response = await postHttp(EndPoints.logout(), data);
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
