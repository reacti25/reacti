import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/block_list_response.dart';

final class GetBlockUserListApi {
  static final GetBlockUserListApi _singleton = GetBlockUserListApi._internal();
  GetBlockUserListApi._internal();

  static GetBlockUserListApi get instance => _singleton;

  Future<BlockListResponse> getBlockUserList() async {
    try {
      Response response = await getHttp(EndPoints.blockedUserList());
      if (response.statusCode == 200) {
        final data = BlockListResponse.fromRawJson(json.encode(response.data));
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
