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

/// Reactive wrapper around [DeclineRequestApi] that pushes the
/// decline-request result into a broadcast stream.
///
/// Extends [RxResponseInt] with a [Map] payload so the success body and any
/// error are observable by widgets via [getFileData].
final class DeclineRequestRx extends RxResponseInt<Map> {
  /// Creates the Rx data source; [empty] and [dataFetcher] are forwarded to
  /// [RxResponseInt].
  DeclineRequestRx({required super.empty, required super.dataFetcher});

  /// The stream of decline-request results, exposed read-only to consumers.
  ValueStream get getFileData => dataFetcher.stream;

  /// The shared HTTP data source that performs the actual request.
  final api = DeclineRequestApi.instance;

  /// Declines the incoming friend request from the user with the given [id].
  ///
  /// On success the response body is pushed onto [dataFetcher] and `true` is
  /// returned. On failure [handleErrorWithReturn] reports the error and
  /// returns `false`.
  Future<bool> declineRequest({required int id}) async {
    try {
      final data = await api.declineRequest(id: id);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed decline-request call.
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
