import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Low-level HTTP data source for cancelling a friend request the current
/// user previously sent.
///
/// Implemented as a lazy singleton; obtain the shared object via [instance].
final class CancelRequestApi {
  /// The single shared instance, created eagerly on first class access.
  static final CancelRequestApi _singleton = CancelRequestApi._internal();

  /// Private constructor that prevents external instantiation, enforcing the
  /// singleton pattern.
  CancelRequestApi._internal();

  /// The shared [CancelRequestApi] instance for all callers.
  static CancelRequestApi get instance => _singleton;

  /// Sends a `POST` to the cancel-request endpoint to withdraw a pending
  /// outgoing friend request.
  ///
  /// [id] is the recipient's user id, posted as `receiver_id`. Returns the
  /// decoded JSON response body as a [Map] on HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows transport or
  /// decoding errors.
  Future<Map> cancelRequest({required int id}) async {
    try {
      Map data = {'receiver_id': id};
      Response response = await postHttp(EndPoints.cancelRequest(), data);
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
