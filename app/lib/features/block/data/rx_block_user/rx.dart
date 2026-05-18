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

/// Reactive data source for blocking/unblocking a user.
///
/// Bridges [BlockUserApi] with an RxDart [BehaviorSubject] and layers in
/// session handling (logout on HTTP 401) over the base [RxResponseInt].
class BlockUserRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to perform the network call.
  ///
  /// Injectable: in production it defaults to the shared [BlockUserApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final BlockUserApi api;

  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  ///
  /// [api] defaults to the shared [BlockUserApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a
  /// fake.
  BlockUserRx({
    BlockUserApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? BlockUserApi.instance;

  /// Broadcast stream of the latest block-toggle response.
  ValueStream get getFileData => dataFetcher.stream;

  /// Toggles the block state for the user with the given [id].
  ///
  /// Returns `true` on success, or `false` if the request failed.
  Future<bool> blockUser({required int id}) async {
    try {
      final data = await api.blockUser(id: id);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed block toggle by emitting the [error] to subscribers.
  ///
  /// On an HTTP 401 the session is treated as expired: local data is wiped,
  /// the logged-in flag is cleared and the user is routed back to login.
  /// Other [DioException]s surface the backend message as an error toast.
  /// Always returns `false`.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // An expired/invalid token means the session is dead; force re-login.
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
