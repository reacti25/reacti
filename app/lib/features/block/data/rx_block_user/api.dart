import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class BlockUserApi {
  static final BlockUserApi _singleton = BlockUserApi._internal();
  BlockUserApi._internal();

  static BlockUserApi get instance => _singleton;

  Future<Map> blockUser({required int id}) async {
    try {
      Response response = await postHttp(EndPoints.blockAUser(id));
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
