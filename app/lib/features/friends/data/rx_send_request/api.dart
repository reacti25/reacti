import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class SendRequestApi {
  static final SendRequestApi _singleton = SendRequestApi._internal();
  SendRequestApi._internal();

  static SendRequestApi get instance => _singleton;

  Future<Map> sendRequest({required int id}) async {
    try {
      Map data = {'receiver_id': id};
      Response response = await postHttp(EndPoints.sendRequest(), data);
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
