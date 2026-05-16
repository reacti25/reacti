import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for removing a member from a group.
///
/// Implemented as a lazy singleton so callers share one API instance.
final class RemoveMemberApi {
  /// The single shared instance backing [instance].
  static final RemoveMemberApi _singleton = RemoveMemberApi._internal();

  /// Private constructor that enforces the singleton pattern.
  RemoveMemberApi._internal();

  /// The shared [RemoveMemberApi] instance.
  static RemoveMemberApi get instance => _singleton;

  /// Removes member [userId] from the group [groupId].
  ///
  /// Performs a DELETE against [EndPoints.removeMember] and returns the
  /// decoded JSON body on success (HTTP 200). Any non-200 status throws the
  /// default failure from [DataSource]; transport errors are rethrown.
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
