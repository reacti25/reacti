import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for deleting a one-to-one conversation.
///
/// `DELETE /auth/chat/delete/{receiver_id}`. The backend soft-deletes every
/// message in the shared room and then removes the room.
class DeleteChatApi {
  /// Shared instance used by the Rx layer.
  static final DeleteChatApi instance = DeleteChatApi();

  /// Deletes the conversation with [receiverId].
  ///
  /// Returns the decoded JSON body on HTTP 200. Throws the default
  /// [DataSource] failure for any non-200 status, and rethrows transport or
  /// decoding errors so the Rx layer can surface them.
  Future<Map> deleteChat({required int receiverId}) async {
    try {
      final Response response = await deleteHttp(
        EndPoints.deleteChat(receiverId),
      );
      if (response.statusCode == 200) {
        return json.decode(json.encode(response.data)) as Map;
      }
      log('Error: ${response.statusCode}');
      throw DataSource.DEFAULT.getFailure();
    } catch (e) {
      rethrow;
    }
  }
}
