import 'dart:developer';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/profile/model/profile_response.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/stream_cleaner.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/streams.dart';

import '../../../../helpers/di.dart';
import '../../../../networks/rx_base.dart';
import 'api.dart';

/// Reactive data source for the signed-in user's profile.
///
/// Bridges [GetProfileApi] with an RxDart [BehaviorSubject] so screens such
/// as the profile and edit-profile views can rebuild whenever the profile
/// is (re)fetched. Layers session handling (logout on HTTP 401) over the
/// base [RxResponseInt].
class GetProfileRx extends RxResponseInt<ProfileResponse> {
  /// The underlying HTTP data source used to perform the profile fetch.
  ///
  /// Injectable: in production it defaults to the shared [GetProfileApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final GetProfileApi api;

  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  ///
  /// [api] defaults to the shared [GetProfileApi] singleton when omitted — so
  /// the production call sites are unaffected — and tests may inject a fake.
  GetProfileRx({
    GetProfileApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? GetProfileApi.instance;

  /// Broadcast stream of the latest [ProfileResponse].
  ValueStream get getProfileStream => dataFetcher.stream;

  /// Fetches the current user's profile and publishes it to subscribers.
  ///
  /// Returns `true` on success, or `false` if the request failed.
  Future<bool> getProfile() async {
    try {
      final data = await api.getProfile();
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

  /// Publishes the fetched profile [data] to subscribers and returns it.
  ///
  /// Also mirrors the read-receipts preference into local storage so chat
  /// widgets can gate "seen" rendering synchronously without awaiting a fetch.
  @override
  dynamic handleSuccessWithReturn(dynamic data) {
    appData.write(kKeyIsLoggedIn, true);
    if (data is ProfileResponse && data.data != null) {
      appData.write(kKeyReadReceipts, data.data!.readReceipts);
    }
    dataFetcher.sink.add(data);
    return data;
  }
}
