import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class ViewGroupFileApi {
  static final ViewGroupFileApi _singleton = ViewGroupFileApi._internal();
  ViewGroupFileApi._internal();

  static ViewGroupFileApi get instance => _singleton;

  Future<Map> viewGroupFile({required int id}) async {
    try {
      Response response = await postHttp(EndPoints.viewGroupFile(id));
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
