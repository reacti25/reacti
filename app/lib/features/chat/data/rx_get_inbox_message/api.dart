import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/inbox_response.dart';

final class GetInboxMessageApi {
  static final GetInboxMessageApi _singleton = GetInboxMessageApi._internal();
  GetInboxMessageApi._internal();

  static GetInboxMessageApi get instance => _singleton;

  Future<InboxResponse> getInboxMessage({required int id}) async {
    try {
      Response response = await getHttp(EndPoints.inboxMessage(id));
      if (response.statusCode == 200) {
        final data = InboxResponse.fromRawJson(json.encode(response.data));
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
