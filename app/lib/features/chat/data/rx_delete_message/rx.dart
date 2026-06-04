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
class DeleteMessageRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to delete the message.
  ///
  /// Injectable: in production it defaults to the shared
  /// [DeleteMessageApi] singleton, but a test can pass a fake so the Rx
  /// logic can be exercised without real HTTP.
  final DeleteMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ///
  /// [api] defaults to the shared [DeleteMessageApi] singleton when
  /// omitted — so the production call sites are unaffected — and tests
  /// may inject a fake.
  DeleteMessageRx({
    DeleteMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? DeleteMessageApi.instance;

  /// Stream of the latest delete response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

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
