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

/// Reactive wrapper around [ForwardMessageApi].
///
/// Extends [RxResponseInt] so consumers can observe the forward result through
/// a stream rather than awaiting the call directly.
class ForwardMessageRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to forward the message.
  ///
  /// Injectable: defaults to the shared [ForwardMessageApi] singleton in
  /// production; a test can pass a fake.
  final ForwardMessageApi api;

  /// Creates the reactive source with its [empty] value and [dataFetcher].
  ForwardMessageRx({
    ForwardMessageApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? ForwardMessageApi.instance;

  /// Stream of the latest forward response for widgets to observe.
  ValueStream get getChatStream => dataFetcher.stream;

  /// Forwards message [messageId] (of [sourceType]) to [recipients] and pushes
  /// the result onto the stream.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn] which surfaces the server message and returns
  /// `false`.
  Future<bool> forwardMessage({
    required int messageId,
    required String sourceType,
    required List<Map<String, dynamic>> recipients,
  }) async {
    try {
      final data = await api.forwardMessage(
        messageId: messageId,
        sourceType: sourceType,
        recipients: recipients,
      );
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed forward request.
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
          error.response?.data["message"] ?? "Couldn't forward the message",
        );
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
