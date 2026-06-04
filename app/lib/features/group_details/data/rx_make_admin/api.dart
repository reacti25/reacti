import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for promoting a group member to admin.
///
/// Implemented as a lazy singleton so callers share one API instance.
/// Not `final` so a test can supply a fake via `implements MakeGroupAdminApi`.
class MakeGroupAdminApi {
  /// The single shared instance backing [instance].
  static final MakeGroupAdminApi _singleton = MakeGroupAdminApi._internal();

  /// Private constructor that enforces the singleton pattern.
  MakeGroupAdminApi._internal();

  /// The shared [MakeGroupAdminApi] instance.
  static MakeGroupAdminApi get instance => _singleton;

  /// Promotes the member [userId] within the group [groupId] to admin.
  ///
  /// Performs a POST against [EndPoints.addGroupAdmin] and returns the decoded
  /// JSON body on success (HTTP 200). Any non-200 status throws the default
  /// failure from [DataSource]; transport errors are rethrown unchanged.
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
