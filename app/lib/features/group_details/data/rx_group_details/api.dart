import 'dart:convert';

import 'package:achiar_expert_app/features/group_details/model/group_details_response.dart';
import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for fetching a single group's details.
///
/// Implemented as a lazy singleton so callers share one instance and avoid
/// re-creating the API wrapper on every request.
final class GroupDetailsApi {
  /// The single shared instance backing [instance].
  static final GroupDetailsApi _singleton = GroupDetailsApi._internal();

  /// Private constructor that enforces the singleton pattern.
  GroupDetailsApi._internal();

  /// The shared [GroupDetailsApi] instance.
  static GroupDetailsApi get instance => _singleton;

  /// Fetches the details of the group identified by [id].
  ///
  /// Performs a GET against [EndPoints.groupDetails] and parses a successful
  /// (HTTP 200) payload into a [GroupDetailsResponse]. Any non-200 status
  /// throws the default failure from [DataSource]; transport errors are
  /// rethrown unchanged for the caller to handle.
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
