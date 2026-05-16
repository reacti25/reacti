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
import '../../model/get_request_response.dart';
import 'api.dart';

/// Reactive wrapper around [GetSentRequestApi] that publishes the fetched
/// outgoing friend requests on a broadcast stream.
///
/// Extends [RxResponseInt] with a [GetRequestResponse] payload so the sent
/// request list and any error are observable via [getSentRequestStream].
final class GetSentRequestRx extends RxResponseInt<GetRequestResponse> {
  /// Creates the Rx data source; [empty] and [dataFetcher] are forwarded to
  /// [RxResponseInt].
  GetSentRequestRx({required super.empty, required super.dataFetcher});

  /// The stream of sent-request responses, exposed read-only to consumers.
  ValueStream get getSentRequestStream => dataFetcher.stream;

  /// The shared HTTP data source that performs the actual request.
  final api = GetSentRequestApi.instance;

  /// Fetches the outgoing friend requests and publishes them on [dataFetcher].
  ///
  /// Returns `true` once the response has been pushed to the stream. On
  /// failure [handleErrorWithReturn] reports the error and returns `false`.
  Future<bool> getSentRequestList() async {
    try {
      final data = await api.getSentRequest();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed sent-requests fetch.
  ///
  /// Overrides [RxResponseInt.handleErrorWithReturn]: a `401` clears local
  /// data and routes to the login screen, while any other [DioException]
  /// surfaces the server message via a toast. The error is logged, added to
  /// [dataFetcher], and `false` is returned.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // A 401 means the session expired; wipe local state and force re-login.
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
