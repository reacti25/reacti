import 'dart:developer';

import 'package:reacti_app/features/privacy/model/privacy_response.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive wrapper around [GetPrivacyApi] that streams the Privacy Policy.
///
/// Extends [RxResponseInt] so the fetched [PrivacyResponse] is pushed through
/// a [BehaviorSubject] that screens listen to via [getPrivacyStream].
class GetPrivacyRx extends RxResponseInt<PrivacyResponse> {
  /// The API data source used to perform the network request.
  ///
  /// Injectable: in production it defaults to the shared [GetPrivacyApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final GetPrivacyApi api;

  /// Creates the Rx wrapper, forwarding [empty] and [dataFetcher] to the base.
  ///
  /// [api] defaults to the shared [GetPrivacyApi] singleton when omitted —
  /// so the production call sites are unaffected — and tests may inject a
  /// fake.
  GetPrivacyRx({
    GetPrivacyApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GetPrivacyApi.instance;

  /// Broadcast stream emitting the latest [PrivacyResponse] or an error.
  ValueStream get getPrivacyStream => dataFetcher.stream;

  /// Fetches the Privacy Policy and pushes it onto [getPrivacyStream].
  ///
  /// Returns `true` when the request succeeds, otherwise delegates to
  /// [handleErrorWithReturn] which returns `false`.
  Future<bool> getPrivacy() async {
    try {
      final data = await api.getPrivacy();
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed privacy fetch.
  ///
  /// On an HTTP 401 the local session is wiped via [totalDataClean] and the
  /// user is sent back to the login screen. Other [DioException]s are logged.
  /// The [error] is also pushed onto [dataFetcher] so the UI can react.
  /// Always returns `false` to signal failure to [getPrivacy].
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
        log(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
