import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../send_retry.dart';

/// HTTP data source for sending a message in a one-to-one chat.
///
/// A lazily-created singleton; the reactive [SendMessageRx] wrapper
/// delegates network work here. Supports text, typed messages
/// (including `reaction` clips from the patent flow), and file uploads.
/// Not `final` so a test can supply a fake via `implements SendMessageApi`.
class SendMessageApi {
  /// The single shared instance backing [instance].
  static final SendMessageApi _singleton = SendMessageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  SendMessageApi._internal();

  /// The shared [SendMessageApi] instance.
  static SendMessageApi get instance => _singleton;

  /// Sends a message to the conversation identified by [id].
  ///
  /// [message] is the optional text body and [type] the message type
  /// (e.g. `reaction` for the silent-recording clip). [file] is an
  /// optional attachment, only uploaded if it exists on disk.
  /// [onSendProgress] reports multipart upload progress, and
  /// [replyToId] threads the message as a reply.
  ///
  /// Returns the decoded JSON response body as a [Map] on HTTP 200.
  /// Throws the default [DataSource] failure for any other status, and
  /// rethrows any transport error raised by the Dio client.
  Future<Map> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) {
    // Bounded retry on pre-delivery transport failures only (see withSendRetry)
    // so a flaky network doesn't silently drop a send — including the patented
    // reaction upload — without risking a duplicate. The FormData is rebuilt on
    // each attempt because a Dio FormData is single-use.
    return withSendRetry(() async {
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
    });
  }
}
