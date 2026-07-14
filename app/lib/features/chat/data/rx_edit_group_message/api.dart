import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for editing the text of a single group message.
///
/// A lazily-created singleton so callers share one instance; the reactive
/// [EditGroupMessageRx] wrapper delegates network work here. Not `final` so a
/// test can supply a fake via `implements EditGroupMessageApi`.
class EditGroupMessageApi {
  /// The single shared instance backing [instance].
  static final EditGroupMessageApi _singleton = EditGroupMessageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  EditGroupMessageApi._internal();

  /// The shared [EditGroupMessageApi] instance.
  static EditGroupMessageApi get instance => _singleton;

  /// Edits group [groupId]'s message [messageId], replacing its text with
  /// [text].
  ///
  /// Returns the decoded JSON response body as a [Map] on HTTP 200. Throws the
  /// default [DataSource] failure for any other status, and rethrows any
  /// transport error (including the 4xx raised for a rejected edit).
  Future<Map> editGroupMessage({
    required int groupId,
    required int messageId,
    required String text,
  }) async {
    try {
      Response response = await postHttp(
        EndPoints.editGroupMessage(groupId, messageId),
        {'text': text},
      );
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
