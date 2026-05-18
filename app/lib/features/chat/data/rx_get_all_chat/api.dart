import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/chat/model/chat_list_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for loading the user's chat list.
///
/// A lazily-created singleton; the reactive [GetAllChatRx] wrapper
/// delegates network work here. Not `final` so a test can supply a
/// fake via `implements GetAllChatApi`.
class GetAllChatApi {
  /// The single shared instance backing [instance].
  static final GetAllChatApi _singleton = GetAllChatApi._internal();

  /// Private constructor enforcing the singleton pattern.
  GetAllChatApi._internal();

  /// The shared [GetAllChatApi] instance.
  static GetAllChatApi get instance => _singleton;

  /// Fetches the full chat list for the current user.
  ///
  /// Returns a parsed [ChatListResponse] on HTTP 200. Throws the
  /// default [DataSource] failure for any other status, and rethrows
  /// any transport error raised by the Dio client.
  Future<ChatListResponse> getAllChat() async {
    try {
      Response response = await getHttp(EndPoints.chatList());
      if (response.statusCode == 200) {
        final data = ChatListResponse.fromRawJson(json.encode(response.data));
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
