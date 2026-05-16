import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/friends/model/get_request_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Low-level HTTP data source for fetching the friend requests the current
/// user has sent and that are still pending.
///
/// Implemented as a lazy singleton; obtain the shared object via [instance].
final class GetSentRequestApi {
  /// The single shared instance, created eagerly on first class access.
  static final GetSentRequestApi _singleton = GetSentRequestApi._internal();

  /// Private constructor that prevents external instantiation, enforcing the
  /// singleton pattern.
  GetSentRequestApi._internal();

  /// The shared [GetSentRequestApi] instance for all callers.
  static GetSentRequestApi get instance => _singleton;

  /// Sends a `GET` to the sent-requests endpoint and parses the result.
  ///
  /// Returns a [GetRequestResponse] decoded from the JSON body on HTTP 200.
  /// Throws the default [DataSource] failure for any non-200 status, and
  /// rethrows transport or decoding errors.
  Future<GetRequestResponse> getSentRequest() async {
    try {
      Response response = await getHttp(EndPoints.getSentRequestList());
      if (response.statusCode == 200) {
        final data = GetRequestResponse.fromRawJson(json.encode(response.data));
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
