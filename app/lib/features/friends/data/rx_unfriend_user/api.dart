import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Low-level HTTP data source for removing an existing friend.
///
/// Implemented as a lazy singleton; obtain the shared object via [instance].
final class UnfriendUserApi {
  /// The single shared instance, created eagerly on first class access.
  static final UnfriendUserApi _singleton = UnfriendUserApi._internal();

  /// Private constructor that prevents external instantiation, enforcing the
  /// singleton pattern.
  UnfriendUserApi._internal();

  /// The shared [UnfriendUserApi] instance for all callers.
  static UnfriendUserApi get instance => _singleton;

  /// Sends a `DELETE` to the unfriend endpoint to end a friendship.
  ///
  /// [id] is the friend's user id, embedded in the request path. Returns the
  /// decoded JSON response body as a [Map] on HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows transport or
  /// decoding errors.
  Future<Map> unfriendUser({required int id}) async {
    try {
      Response response = await deleteHttp(EndPoints.unfriendUser(id));
      if (response.statusCode == 200) {
        // Round-trip through json encode/decode to obtain a plain Map detached
        // from Dio's response object.
        final data = json.decode(json.encode(response.data));
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
