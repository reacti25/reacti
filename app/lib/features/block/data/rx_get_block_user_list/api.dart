import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/block_list_response.dart';

/// Thin HTTP wrapper for fetching the signed-in user's blocked-user list.
///
/// Implemented as a lazy singleton since it holds no per-call state.
final class GetBlockUserListApi {
  /// The single shared instance, created lazily on first access.
  static final GetBlockUserListApi _singleton = GetBlockUserListApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  GetBlockUserListApi._internal();

  /// The shared [GetBlockUserListApi] instance.
  static GetBlockUserListApi get instance => _singleton;

  /// Fetches the list of users the current user has blocked.
  ///
  /// Returns a parsed [BlockListResponse] on HTTP 200. Throws the default
  /// [DataSource] failure for any other status code and rethrows
  /// transport-level errors.
  Future<BlockListResponse> getBlockUserList() async {
    try {
      Response response = await getHttp(EndPoints.blockedUserList());
      if (response.statusCode == 200) {
        final data = BlockListResponse.fromRawJson(json.encode(response.data));
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
