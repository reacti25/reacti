import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/chat/model/chat_list_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

final class GetAllChatApi {
  static final GetAllChatApi _singleton = GetAllChatApi._internal();
  GetAllChatApi._internal();

  static GetAllChatApi get instance => _singleton;

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
