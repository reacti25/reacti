import 'dart:developer';

import 'package:achiar_expert_app/features/search/model/all_user_response.dart';
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

/// Reactive wrapper around [SearchApi] that streams user-search results.
///
/// Extends [RxResponseInt] so search results ([AllUserResponse]) flow through
/// a [BehaviorSubject] that the search screen rebuilds from.
final class SearchUserRx extends RxResponseInt<AllUserResponse> {
  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  SearchUserRx({required super.empty, required super.dataFetcher});

  /// Broadcast stream emitting the latest [AllUserResponse] or an error.
  ValueStream get getSearchStream => dataFetcher.stream;

  /// The API data source used to perform the search request.
  final api = SearchApi.instance;

  /// Runs a user search for [search] and pushes results onto [getSearchStream].
  ///
  /// Returns `true` on success, otherwise delegates to [handleErrorWithReturn]
  /// which returns `false`.
  Future<bool> searchUser({required String search}) async {
    try {
      final data = await api.searchUser(search: search);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed user search.
  ///
  /// On an HTTP 401 the session is wiped via [totalDataClean] and the user is
  /// sent to login. Other [DioException]s surface a toast with the backend
  /// message. The [error] is pushed onto [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response!.statusCode == 401) {
        // A 401 means the token is no longer valid: clear the session and
        // force re-authentication rather than retrying.
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
