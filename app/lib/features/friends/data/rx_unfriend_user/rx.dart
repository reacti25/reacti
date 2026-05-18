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

/// Reactive wrapper around [UnfriendUserApi] that pushes the unfriend result
/// into a broadcast stream.
///
/// Extends [RxResponseInt] with a [Map] payload so the success body and any
/// error are observable by widgets via [getFileData].
class UnfriendUserRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to perform the request.
  ///
  /// Injectable: in production it defaults to the shared [UnfriendUserApi]
  /// singleton, but a test can pass a fake so the Rx logic can be exercised
  /// without real HTTP.
  final UnfriendUserApi api;

  /// Creates the Rx data source.
  ///
  /// [api] defaults to the shared [UnfriendUserApi] singleton when omitted —
  /// so production call sites are unaffected — and tests may inject a fake.
  /// [empty] and [dataFetcher] are forwarded to [RxResponseInt].
  UnfriendUserRx({
    UnfriendUserApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? UnfriendUserApi.instance;

  /// The stream of unfriend results, exposed read-only to consumers.
  ValueStream get getFileData => dataFetcher.stream;

  /// Removes the friend with the given [id] from the current user's friends.
  ///
  /// On success the response body is pushed onto [dataFetcher] and `true` is
  /// returned. On failure [handleErrorWithReturn] reports the error and
  /// returns `false`.
  Future<bool> unfriendUser({required int id}) async {
    try {
      final data = await api.unfriendUser(id: id);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed unfriend call.
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
