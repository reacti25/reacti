import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/all_user_response.dart';

final class SearchApi {
  static final SearchApi _singleton = SearchApi._internal();
  SearchApi._internal();

  static SearchApi get instance => _singleton;

  Future<AllUserResponse> searchUser({required String search}) async {
    try {
      Map data = {'search': search};
      Response response = await getHttp(EndPoints.searchUser(search), data);
      if (response.statusCode == 200) {
        final data = AllUserResponse.fromRawJson(json.encode(response.data));
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
