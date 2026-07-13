import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for editing the text of a single 1:1 chat message.
///
/// A lazily-created singleton so callers share one instance; the reactive
/// [EditMessageRx] wrapper delegates network work here. Not `final` so a test
/// can supply a fake via `implements EditMessageApi`.
class EditMessageApi {
  /// The single shared instance backing [instance].
  static final EditMessageApi _singleton = EditMessageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  EditMessageApi._internal();

  /// The shared [EditMessageApi] instance.
  static EditMessageApi get instance => _singleton;

  /// Sends an edit request replacing message [messageId]'s text with [text].
  ///
  /// Returns the decoded JSON response body as a [Map] on HTTP 200. Throws the
  /// default [DataSource] failure for any other status, and rethrows any
  /// transport error (including the 4xx a Dio client raises for a rejected
  /// edit — not the sender, or past the edit window).
  Future<Map> editMessage({
    required int messageId,
    required String text,
  }) async {
    try {
      Response response = await postHttp(EndPoints.editMessage(messageId), {
        'text': text,
      });
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
