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
import 'api.dart';

/// Reactive wrapper around [EditMessageApi].
///
/// Extends [RxResponseInt] so consumers can observe the edit result through a
/// stream rather than awaiting the call directly.
class EditMessageRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to edit the message.
  ///
  /// Injectable: defaults to the shared [EditMessageApi] singleton in
  /// production, but a test can pass a fake so the Rx logic can be exercised
  /// without real HTTP.
  final EditMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  EditMessageRx({
    EditMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? EditMessageApi.instance;

  /// Stream of the latest edit response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// Edits message [messageId] to [text] and pushes the result onto the stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which surfaces the server message and returns
  /// `false` (e.g. a past-the-window 422 carries "You can only edit a message
  /// within 10 minutes of sending it.").
  Future<bool> editMessage({
    required int messageId,
    required String text,
  }) async {
    try {
      final data = await api.editMessage(messageId: messageId, text: text);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed edit request.
  ///
  /// On an HTTP 401 the local session is cleared and the user is sent back to
  /// the login screen; other [DioException]s surface a toast with the server
  /// message (e.g. the edit-window rejection). Returns `false` to signal
  /// failure so the caller can keep the composer in edit mode.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        ToastUtil.showErrorMessage(
          error.response?.data["message"] ?? "Couldn't edit the message",
        );
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
