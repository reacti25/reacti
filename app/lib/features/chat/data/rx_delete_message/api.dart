import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class DeleteMessageApi {
  static final DeleteMessageApi _singleton = DeleteMessageApi._internal();
  DeleteMessageApi._internal();

  static DeleteMessageApi get instance => _singleton;

  Future<Map> deleteMessage({required int messageId}) async {
    try {
      Map data = {'message_id': messageId};
      Response response = await deleteHttp(EndPoints.deleteMessage(), data);
      if (response.statusCode == 200) {
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
