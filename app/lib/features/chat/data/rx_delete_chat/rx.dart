import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/rx_base.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive wrapper for deleting a one-to-one conversation.
///
/// The backend route has existed and been tested since launch; nothing in the
/// app ever called it, so there was no way to delete a chat at all.
class DeleteChatRx extends RxResponseInt<Map> {
  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [DeleteChatApi] singleton when omitted, so
  /// production call sites are unaffected, and tests may inject a fake.
  DeleteChatRx({
    DeleteChatApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? DeleteChatApi.instance;

  /// The HTTP data source used to delete a conversation.
  final DeleteChatApi api;

  /// The broadcast stream of the most recent delete response.
  ValueStream get getFileData => dataFetcher.stream;

  /// Deletes the conversation with [receiverId].
  ///
  /// Returns `true` once the response has been emitted, or `false` when
  /// [handleErrorWithReturn] handles a failure.
  Future<bool> deleteChat({required int receiverId}) async {
    try {
      final data = await api.deleteChat(receiverId: receiverId);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed request, returning `false` instead of rethrowing.
  ///
  /// On an HTTP 401 the local session is wiped and the user is sent back to
  /// the login screen; other [DioException]s only have their server message
  /// logged. The error is still pushed onto [dataFetcher] for listeners.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log('Delete chat failed: ${error.response?.data}');
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
