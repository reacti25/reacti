import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for forwarding a message to one or more recipients.
///
/// A lazily-created singleton so callers share one instance; the reactive
/// [ForwardMessageRx] wrapper delegates network work here. Not `final` so a
/// test can supply a fake via `implements ForwardMessageApi`.
class ForwardMessageApi {
  /// The single shared instance backing [instance].
  static final ForwardMessageApi _singleton = ForwardMessageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  ForwardMessageApi._internal();

  /// The shared [ForwardMessageApi] instance.
  static ForwardMessageApi get instance => _singleton;

  /// Forwards message [messageId] (of [sourceType] `single`|`group`) to every
  /// recipient in [recipients], each a map `{type: single|group, id: int}`.
  ///
  /// Returns the decoded JSON response on HTTP 200; throws the default
  /// [DataSource] failure otherwise and rethrows transport errors.
  Future<Map> forwardMessage({
    required int messageId,
    required String sourceType,
    required List<Map<String, dynamic>> recipients,
  }) async {
    try {
      Response response = await postHttp(EndPoints.forwardMessage(), {
        'message_id': messageId,
        'source_type': sourceType,
        'recipients': recipients,
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
