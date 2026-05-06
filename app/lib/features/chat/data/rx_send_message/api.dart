import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class SendMessageApi {
  static final SendMessageApi _singleton = SendMessageApi._internal();
  SendMessageApi._internal();

  static SendMessageApi get instance => _singleton;

  Future<Map> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    try {
      FormData data = FormData.fromMap({
        'text': message,
        'message_type': type,
        'reply_to_id': replyToId,
      });

      if (file != null && await File(file.path).exists()) {
        data.files.add(
          MapEntry('file', await MultipartFile.fromFile(file.path)),
        );
      }
      Response response = await postHttp(
        EndPoints.sendMessage(id),
        data,
        onSendProgress, // Add the onSendProgress callback here
      );

      log("Send Data ==============> ${file != null ? file.path : 'No File'}");
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
