import 'dart:convert';

import 'package:achiar_expert_app/features/privacy/model/privacy_response.dart';
import 'package:dio/dio.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class GetPrivacyApi {
  static final GetPrivacyApi _singleton = GetPrivacyApi._internal();
  GetPrivacyApi._internal();

  static GetPrivacyApi get instance => _singleton;

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
