import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for deleting a single chat message.
///
/// A lazily-created singleton so callers share one instance; the
/// reactive [DeleteMessageRx] wrapper delegates network work here.
final class DeleteMessageApi {
  /// The single shared instance backing [instance].
  static final DeleteMessageApi _singleton = DeleteMessageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  DeleteMessageApi._internal();

  /// The shared [DeleteMessageApi] instance.
  static DeleteMessageApi get instance => _singleton;

  /// Sends a delete request for the message identified by [messageId].
  ///
  /// Returns the decoded JSON response body as a [Map] on HTTP 200.
  /// Throws the default [DataSource] failure for any other status, and
  /// rethrows any transport error raised by the Dio client.
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
