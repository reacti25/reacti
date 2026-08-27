import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for leaving a group.
///
/// `POST /auth/group/{id}/leave`. The backend removes the caller's membership
/// and broadcasts to the remaining members.
class LeaveGroupApi {
  /// Shared instance used by the Rx layer.
  static final LeaveGroupApi instance = LeaveGroupApi();

  /// Leaves the group identified by [groupId].
  ///
  /// Returns the decoded JSON body on HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows transport or
  /// decoding errors so the Rx layer can surface them.
  Future<Map> leaveGroup({required int groupId}) async {
    try {
      final Response response = await postHttp(EndPoints.leaveGroup(groupId));
      if (response.statusCode == 200) {
        return json.decode(json.encode(response.data)) as Map;
      }
      log('Error: ${response.statusCode}');
      throw DataSource.DEFAULT.getFailure();
    } catch (e) {
      rethrow;
    }
  }
}
