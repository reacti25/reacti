import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/inbox_response.dart';

/// HTTP data source for loading a one-to-one chat's inbox messages.
///
/// A lazily-created singleton; the reactive [GetInboxMessageRx] wrapper
/// delegates network work here.
final class GetInboxMessageApi {
  /// The single shared instance backing [instance].
  static final GetInboxMessageApi _singleton = GetInboxMessageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  GetInboxMessageApi._internal();

  /// The shared [GetInboxMessageApi] instance.
  static GetInboxMessageApi get instance => _singleton;

  /// Fetches the message inbox for the conversation identified by [id].
  ///
  /// Returns a parsed [InboxResponse] on HTTP 200. Throws the default
  /// [DataSource] failure for any other status, and rethrows any
  /// transport error raised by the Dio client.
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
