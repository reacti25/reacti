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

/// Reactive wrapper around [DeleteMessageApi].
///
/// Extends [RxResponseInt] so consumers can observe the delete result
/// through a stream rather than awaiting the call directly.
final class DeleteMessageRx extends RxResponseInt<Map> {
  /// Creates the reactive source with its [empty] value and [dataFetcher].
  DeleteMessageRx({required super.empty, required super.dataFetcher});

  /// Stream of the latest delete response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// The underlying HTTP data source.
  final api = DeleteMessageApi.instance;

  /// Deletes the message [messageId] and pushes the result onto the stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which returns `false`.
  Future<bool> deleteMessage({required int messageId}) async {
    try {
      final data = await api.deleteMessage(messageId: messageId);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed delete request.
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
