import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper that registers a device's push-notification token with
/// the backend so the server can deliver FCM messages to this device.
///
/// Implemented as a lazy singleton because the app only ever needs one
/// instance and it carries no per-call state.
/// Not `final` so a test can supply a fake via `implements AddTokenApi`.
class AddTokenApi {
  /// The single shared instance, created lazily on first access.
  static final AddTokenApi _singleton = AddTokenApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  AddTokenApi._internal();

  /// The shared [AddTokenApi] instance.
  static AddTokenApi get instance => _singleton;

  /// Sends the device's FCM [token] to the backend keyed by [deviceId].
  ///
  /// Returns the decoded JSON response body as a [Map] when the server
  /// answers with HTTP 200 or 201. Throws the default [DataSource] failure
  /// for any other status code, and rethrows any transport-level error.
  Future<Map> addToken({
    required String deviceId,
    required String token,
  }) async {
    try {
      Map data = {'device_id': deviceId, 'token': token};
      Response response = await postHttp(EndPoints.addToken(), data);
      if (response.statusCode == 200 || response.statusCode == 201) {
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
