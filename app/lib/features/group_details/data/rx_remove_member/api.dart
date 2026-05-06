import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class RemoveMemberApi {
  static final RemoveMemberApi _singleton = RemoveMemberApi._internal();
  RemoveMemberApi._internal();

  static RemoveMemberApi get instance => _singleton;

  Future<Map> removeMember({required int groupId, required int userId}) async {
    try {
      Response response = await deleteHttp(
        EndPoints.removeMember(groupId, userId),
      );

      if (response.statusCode == 200) {
        final data = json.decode(json.encode(response.data));
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
