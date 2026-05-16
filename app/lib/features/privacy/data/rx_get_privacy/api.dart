import 'dart:convert';

import 'package:achiar_expert_app/features/privacy/model/privacy_response.dart';
import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source that fetches the Privacy Policy page from the backend.
///
/// Implemented as a lazy singleton so the whole app shares one instance and
/// no per-call construction cost is incurred.
final class GetPrivacyApi {
  /// The single shared instance backing [instance].
  static final GetPrivacyApi _singleton = GetPrivacyApi._internal();

  /// Private constructor enforcing the singleton pattern.
  GetPrivacyApi._internal();

  /// The shared [GetPrivacyApi] instance used by callers.
  static GetPrivacyApi get instance => _singleton;

  /// Fetches the Privacy Policy page from the `getPrivacy` endpoint.
  ///
  /// Returns the parsed [PrivacyResponse] on an HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows any transport
  /// or parsing error so the caller can surface it.
  Future<PrivacyResponse> getPrivacy() async {
    try {
      Response response = await getHttp(EndPoints.getPrivacy());

      if (response.statusCode == 200) {
        final data = PrivacyResponse.fromRawJson(json.encode(response.data));
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
