import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';
import '../../model/group_media_response.dart';

/// HTTP data source for fetching the media shared within a group.
///
/// Implemented as a lazy singleton so the media tab reuses one API instance.
/// Not `final` so a test can supply a fake via `implements GroupMediaApi`.
class GroupMediaApi {
  /// The single shared instance backing [instance].
  static final GroupMediaApi _singleton = GroupMediaApi._internal();

  /// Private constructor that enforces the singleton pattern.
  GroupMediaApi._internal();

  /// The shared [GroupMediaApi] instance.
  static GroupMediaApi get instance => _singleton;

  /// Fetches the paginated media list for the group identified by [id].
  ///
  /// Performs a GET against [EndPoints.groupMedia] and parses a successful
  /// (HTTP 200) payload into a [GroupMediaResponse]. Any non-200 status
  /// throws the default failure from [DataSource]; transport errors are
  /// rethrown unchanged.
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
