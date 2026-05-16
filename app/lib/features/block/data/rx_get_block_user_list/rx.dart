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
import '../../model/block_list_response.dart';
import 'api.dart';

/// Reactive data source for the signed-in user's blocked-user list.
///
/// Bridges [GetBlockUserListApi] with an RxDart [BehaviorSubject] so the
/// block screen rebuilds whenever the list is (re)fetched. Layers in session
/// handling (logout on HTTP 401) over the base [RxResponseInt].
final class GetBlockUserListRx extends RxResponseInt<BlockListResponse> {
  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  GetBlockUserListRx({required super.empty, required super.dataFetcher});

  /// Broadcast stream of the latest [BlockListResponse].
  ValueStream get getBlockListStream => dataFetcher.stream;

  /// The underlying HTTP client used to perform the network call.
  final api = GetBlockUserListApi.instance;

  /// Fetches the blocked-user list and publishes it to subscribers.
  ///
  /// Returns `true` on success, or `false` if the request failed.
  Future<bool> getBlockUserList() async {
    try {
      final data = await api.getBlockUserList();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed fetch by emitting the [error] to subscribers.
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
