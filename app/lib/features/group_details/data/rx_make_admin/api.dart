import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class MakeGroupAdminApi {
  static final MakeGroupAdminApi _singleton = MakeGroupAdminApi._internal();
  MakeGroupAdminApi._internal();

  static MakeGroupAdminApi get instance => _singleton;

  Future<Map> makeGroupAdmin({
    required int groupId,
    required int userId,
  }) async {
    try {
      Response response = await postHttp(
        EndPoints.addGroupAdmin(groupId, userId),
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
