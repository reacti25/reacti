import 'dart:convert';
import 'dart:developer';

import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for loading a group chat's inbox messages.
///
/// A lazily-created singleton; the reactive [GetGroupInboxRx] wrapper
/// delegates network work here. Not `final` so a test can supply a
/// fake via `implements GetGroupInboxApi`.
class GetGroupInboxApi {
  /// The single shared instance backing [instance].
  static final GetGroupInboxApi _singleton = GetGroupInboxApi._internal();

  /// Private constructor enforcing the singleton pattern.
  GetGroupInboxApi._internal();

  /// The shared [GetGroupInboxApi] instance.
  static GetGroupInboxApi get instance => _singleton;

  /// Fetches the message inbox for the group identified by [id].
  ///
  /// When [limit] is given, requests cursor pagination: the newest [limit]
  /// messages, or — with [before] (a message id) — the page of messages older
  /// than it (`data.pagination.has_more` signals whether older pages remain).
  /// With no [limit] the backend returns the full thread (back-compat).
  ///
  /// Returns a parsed [GroupInboxResponse] on HTTP 200. Throws the
  /// default [DataSource] failure for any other status, and rethrows
  /// any transport error raised by the Dio client.
  Future<GroupInboxResponse> getGroupInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    try {
      var path = EndPoints.groupInbox(id);
      final query = <String>[
        if (limit != null) 'limit=$limit',
        if (before != null) 'before=$before',
      ];
      if (query.isNotEmpty) {
        path = '$path?${query.join('&')}';
      }
      Response response = await getHttp(path);
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
