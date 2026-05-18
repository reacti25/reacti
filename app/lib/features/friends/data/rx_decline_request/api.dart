import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Low-level HTTP data source for declining an incoming friend request.
///
/// Implemented as a lazy singleton; obtain the shared object via [instance].
///
/// Not `final` so a test can supply a fake via `implements DeclineRequestApi`.
class DeclineRequestApi {
  /// The single shared instance, created eagerly on first class access.
  static final DeclineRequestApi _singleton = DeclineRequestApi._internal();

  /// Private constructor that prevents external instantiation, enforcing the
  /// singleton pattern.
  DeclineRequestApi._internal();

  /// The shared [DeclineRequestApi] instance for all callers.
  static DeclineRequestApi get instance => _singleton;

  /// Sends a `POST` to the decline-request endpoint to reject a pending
  /// incoming friend request.
  ///
  /// [id] is the sender's user id, posted as `sender_id`. Returns the decoded
  /// JSON response body as a [Map] on HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows transport or
  /// decoding errors.
  Future<Map> declineRequest({required int id}) async {
    try {
      Map data = {'sender_id': id};
      Response response = await postHttp(EndPoints.declineRequest(), data);
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
