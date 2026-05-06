import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class DeclineRequestApi {
  static final DeclineRequestApi _singleton = DeclineRequestApi._internal();
  DeclineRequestApi._internal();

  static DeclineRequestApi get instance => _singleton;

  Future<Map> declineRequest({required int id}) async {
    try {
      Map data = {'sender_id': id};
      Response response = await postHttp(EndPoints.declineRequest(), data);
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
