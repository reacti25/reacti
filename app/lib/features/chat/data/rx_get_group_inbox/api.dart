import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/chat/model/group_inbox_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class GetGroupInboxApi {
  static final GetGroupInboxApi _singleton = GetGroupInboxApi._internal();
  GetGroupInboxApi._internal();

  static GetGroupInboxApi get instance => _singleton;

  Future<GroupInboxResponse> getGroupInboxMessage({required int id}) async {
    try {
      Response response = await getHttp(EndPoints.groupInbox(id));
      if (response.statusCode == 200) {
        final data = GroupInboxResponse.fromRawJson(json.encode(response.data));
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
