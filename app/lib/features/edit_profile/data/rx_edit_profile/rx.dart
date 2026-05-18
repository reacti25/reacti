import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

/// Reactive data source for profile updates.
///
/// Bridges [EditProfileApi] with an RxDart [BehaviorSubject] and layers in
/// session handling (logout on HTTP 401) over the base [RxResponseInt].
class EditProfileRx extends RxResponseInt<Map> {
  /// The underlying HTTP data source used to perform the update request.
  ///
  /// Injectable: in production it defaults to the shared [EditProfileApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final EditProfileApi api;

  /// Creates the data source with the [empty] seed value and the
  /// [dataFetcher] stream controller supplied by the DI layer.
  ///
  /// [api] defaults to the shared [EditProfileApi] singleton when omitted — so
  /// the production call sites are unaffected — and tests may inject a fake.
  EditProfileRx({
    EditProfileApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? EditProfileApi.instance;

  /// Broadcast stream of the latest profile-update response.
  ValueStream get getFileData => dataFetcher.stream;

  /// Updates the user's profile and publishes the response to subscribers.
  ///
  /// [fName] and [lName] are required; [avatar], [phone] and [bio] are
  /// optional. Returns `true` on success, or `false` if the request failed.
  Future<bool> userEditProfile({
    required String fName,
    required String lName,
    XFile? avatar,
    String? phone,
    String? bio,
  }) async {
    try {
      final data = await api.userEditProfile(
        fName: fName,
        lName: lName,
        avatar: avatar,
        phone: phone,
        bio: bio,
      );
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Handles a failed update by emitting the [error] to subscribers.
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
}
