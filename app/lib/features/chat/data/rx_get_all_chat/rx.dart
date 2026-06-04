import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../helpers/toast.dart';
import '../../../../networks/rx_base.dart';
import '../../../../networks/stream_cleaner.dart';
import '../../model/chat_list_response.dart';
import 'api.dart';

/// Reactive wrapper around [GetAllChatApi].
///
/// Extends [RxResponseInt] so the chat-list screen can observe the
/// loaded [ChatListResponse] through a stream.
class GetAllChatRx extends RxResponseInt<ChatListResponse> {
  /// The underlying HTTP data source used to load the chat list.
  ///
  /// Injectable: in production it defaults to the shared [GetAllChatApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final GetAllChatApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ///
  /// [api] defaults to the shared [GetAllChatApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a
  /// fake.
  GetAllChatRx({
    GetAllChatApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GetAllChatApi.instance;

  /// Stream of the latest chat list for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// Loads the chat list and pushes the result onto the stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which returns `false`.
  Future<bool> getAllChat() async {
    try {
      final data = await api.getAllChat();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed chat-list request.
  ///
  /// On an HTTP 401 the local session is cleared and the user is sent
  /// back to the login screen; other [DioException]s surface a toast
  /// with the server message. The [error] is logged and forwarded to
  /// the stream, and `false` is returned to signal failure.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        ToastUtil.showErrorMessage(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
