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

/// Reactive wrapper around [EditGroupMessageApi].
///
/// Extends [RxResponseInt] so consumers can observe the edit result through a
/// stream rather than awaiting the call directly.
class EditGroupMessageRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to edit the group message.
  ///
  /// Injectable: defaults to the shared [EditGroupMessageApi] singleton in
  /// production; a test can pass a fake.
  final EditGroupMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  EditGroupMessageRx({
    EditGroupMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? EditGroupMessageApi.instance;

  /// Stream of the latest edit response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// Edits group [groupId]'s message [messageId] to [text] and pushes the
  /// result onto the stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which surfaces the server message and returns
  /// `false`.
  Future<bool> editGroupMessage({
    required int groupId,
    required int messageId,
    required String text,
  }) async {
    try {
      final data = await api.editGroupMessage(
        groupId: groupId,
        messageId: messageId,
        text: text,
      );
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
  /// message. Returns `false` to signal failure.
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
