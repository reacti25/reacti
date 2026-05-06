import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class AddTokenApi {
  static final AddTokenApi _singleton = AddTokenApi._internal();
  AddTokenApi._internal();

  static AddTokenApi get instance => _singleton;

  Future<Map> addToken({
    required String deviceId,
    required String token,
  }) async {
    
    try {
      Map data = {'device_id': deviceId, 'token': token};
      Response response = await postHttp(EndPoints.addToken(), data);
      if (response.statusCode == 200 || response.statusCode == 201) {
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
