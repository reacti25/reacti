import 'dart:developer';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/networks/stream_cleaner.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../helpers/di.dart';
import '../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive data source for account deletion.
///
/// Bridges [DeleteAccountApi] with an RxDart [BehaviorSubject] and layers in
/// session handling (logout on HTTP 401) over the base [RxResponseInt].
class DeleteAccountRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to perform the deletion request.
  ///
  /// Injectable: in production it defaults to the shared [DeleteAccountApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final DeleteAccountApi api;

  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  ///
  /// [api] defaults to the shared [DeleteAccountApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a fake.
  DeleteAccountRx({
    DeleteAccountApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? DeleteAccountApi.instance;

  /// Broadcast stream of the latest account-deletion response.
  ValueStream get collectionStream => dataFetcher.stream;

  /// Deletes the current user's account.
  ///
  /// Returns `true` once the response has been pushed to subscribers, or
  /// `false` if the request failed.
  Future<bool> deleteAccount() async {
    try {
      final data = await api.deleteAccount();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed deletion by emitting the [error] to subscribers.
  ///
  /// On an HTTP 401 the session is treated as expired: local data is wiped,
  /// the logged-in flag is cleared and the user is routed back to login.
  /// Other [DioException]s are simply logged. Always returns `false`.
  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      // An expired/invalid token means the session is dead; force re-login.
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }

  /// Publishes the successful deletion [data] to subscribers and returns it.
  @override
  dynamic handleSuccessWithReturn(dynamic data) {
    appData.write(kKeyIsLoggedIn, true);
    dataFetcher.sink.add(data);
    return data;
  }
}
