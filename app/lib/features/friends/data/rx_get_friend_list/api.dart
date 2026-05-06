import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/friend_list_response.dart';

final class GetFriendListApi {
  static final GetFriendListApi _singleton = GetFriendListApi._internal();
  GetFriendListApi._internal();

  static GetFriendListApi get instance => _singleton;

  Future<FriendListResponse> getFriendList() async {
    try {
      Response response = await getHttp(EndPoints.getFriendList());
      if (response.statusCode == 200) {
        final data = FriendListResponse.fromRawJson(json.encode(response.data));
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
