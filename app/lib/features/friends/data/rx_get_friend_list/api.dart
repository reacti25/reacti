import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/friend_list_response.dart';

/// Low-level HTTP data source for fetching the current user's friend list.
///
/// Implemented as a lazy singleton; obtain the shared object via [instance].
final class GetFriendListApi {
  /// The single shared instance, created eagerly on first class access.
  static final GetFriendListApi _singleton = GetFriendListApi._internal();

  /// Private constructor that prevents external instantiation, enforcing the
  /// singleton pattern.
  GetFriendListApi._internal();

  /// The shared [GetFriendListApi] instance for all callers.
  static GetFriendListApi get instance => _singleton;

  /// Sends a `GET` to the friend-list endpoint and parses the result.
  ///
  /// Returns a [FriendListResponse] decoded from the JSON body on HTTP 200.
  /// Throws the default [DataSource] failure for any non-200 status, and
  /// rethrows transport or decoding errors.
  Future<FriendListResponse> getFriendList() async {
    try {
      Response response = await getHttp(EndPoints.getFriendList());
      if (response.statusCode == 200) {
        final data = FriendListResponse.fromRawJson(json.encode(response.data));
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
