import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Low-level HTTP data source for accepting an incoming friend request.
///
/// Implemented as a lazy singleton so the whole app shares one instance and
/// no per-call allocation is needed. Use [instance] to obtain it.
///
/// Not `final` so a test can supply a fake via `implements AcceptRequestApi`.
class AcceptRequestApi {
  /// The single shared instance, created eagerly on first class access.
  static final AcceptRequestApi _singleton = AcceptRequestApi._internal();

  /// Private constructor that prevents external instantiation, enforcing the
  /// singleton pattern.
  AcceptRequestApi._internal();

  /// The shared [AcceptRequestApi] instance for all callers.
  static AcceptRequestApi get instance => _singleton;

  /// Sends a `POST` to the accept-request endpoint to confirm a friendship.
  ///
  /// [id] is the sender's user id, posted as `sender_id`. Returns the decoded
  /// JSON response body as a [Map] on HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows any transport
  /// or decoding error so the calling Rx layer can handle it.
  Future<Map> acceptRequest({required int id}) async {
    try {
      Map data = {'sender_id': id};
      Response response = await postHttp(EndPoints.acceptRequest(), data);
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
