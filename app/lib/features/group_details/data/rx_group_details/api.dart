import 'dart:convert';

import 'package:achiar_expert_app/features/group_details/model/group_details_response.dart';
import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class GroupDetailsApi {
  static final GroupDetailsApi _singleton = GroupDetailsApi._internal();
  GroupDetailsApi._internal();

  static GroupDetailsApi get instance => _singleton;

  Future<GroupDetailsResponse> groupDetails({required int id}) async {
    try {
      Response response = await getHttp(EndPoints.groupDetails(id));

      if (response.statusCode == 200) {
        final data = GroupDetailsResponse.fromRawJson(
          json.encode(response.data),
        );
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
