import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/friends/model/get_request_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class GetSentRequestApi {
  static final GetSentRequestApi _singleton = GetSentRequestApi._internal();
  GetSentRequestApi._internal();

  static GetSentRequestApi get instance => _singleton;

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
