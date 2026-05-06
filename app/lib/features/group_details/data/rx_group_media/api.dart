import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';
import '../../model/group_media_response.dart';

final class GroupMediaApi {
  static final GroupMediaApi _singleton = GroupMediaApi._internal();
  GroupMediaApi._internal();

  static GroupMediaApi get instance => _singleton;

  Future<GroupMediaResponse> groupMediaList({required int id}) async {
    try {
      Response response = await getHttp(EndPoints.groupMedia(id));

      if (response.statusCode == 200) {
        final data = GroupMediaResponse.fromRawJson(json.encode(response.data));
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
