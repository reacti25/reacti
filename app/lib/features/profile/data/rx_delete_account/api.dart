import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class DeleteAccountApi {
  static final DeleteAccountApi _singleton = DeleteAccountApi._internal();
  DeleteAccountApi._internal();

  static DeleteAccountApi get instance => _singleton;

  Future<Map> deleteAccount() async {
    try {
      Response response = await deleteHttp(EndPoints.deleteAccount());
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
