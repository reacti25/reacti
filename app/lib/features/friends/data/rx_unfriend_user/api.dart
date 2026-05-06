import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class UnfriendUserApi {
  static final UnfriendUserApi _singleton = UnfriendUserApi._internal();
  UnfriendUserApi._internal();

  static UnfriendUserApi get instance => _singleton;

  Future<Map> unfriendUser({required int id}) async {
    try {
      Response response = await deleteHttp(EndPoints.unfriendUser(id));
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
