import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/di.dart';
import '../../../../networks/dio/dio.dart';
import '../../model/login_response.dart';
import 'api.dart';

/// Reactive wrapper around [SignUpVerifyApi] that streams the OTP-verification
/// result and persists the resulting session.
///
/// Extends [RxResponseInt] with a [LoginResponse] payload: a successful
/// verification also writes the auth token, login flag and user id to local
/// storage, completing onboarding.
class VerifySignupOtpRx extends RxResponseInt<LoginResponse> {
  /// Last error message captured from a failed verification response, if any.
  String? errorMessage;

  /// The underlying HTTP data source used to perform the verification request.
  ///
  /// Injectable: in production it defaults to the shared [SignUpVerifyApi]
  /// singleton, but a test can pass a fake so the Rx logic can be
  /// exercised without real HTTP.
  final SignUpVerifyApi api;

  /// Creates the Rx wrapper.
  ///
  /// [api] defaults to the shared [SignUpVerifyApi] singleton when omitted —
  /// so the production call sites in `api_access.dart` are unaffected — and
  /// tests may inject a fake. [empty] and [dataFetcher] are forwarded to
  /// [RxResponseInt].
  VerifySignupOtpRx({
    SignUpVerifyApi? api,
    required super.empty,
    required super.dataFetcher,
  }) : api = api ?? SignUpVerifyApi.instance;

  /// The broadcast stream emitting the latest [LoginResponse] or error.
  ValueStream get getFileData => dataFetcher.stream;

  /// Verifies the signup [otp] for [email] and reports whether it succeeded.
  ///
  /// Returns `true` on success; on failure delegates to
  /// [handleErrorWithReturn], which records the message and returns `false`.
  Future<bool> verifySignupOtp({
    required String otp,
    required String email,
  }) async {
    try {
      final data = await api.verifySignupOtp(email: email, otp: otp);
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  /// Persists the authenticated session and emits [data] to listeners.
  ///
  /// Writes the access token, logged-in flag and user id into local storage,
  /// updates the shared [DioSingleton] so future requests are authenticated,
  /// then pushes [data] onto [dataFetcher]. Returns the same [data].
  @override
  handleSuccessWithReturn(LoginResponse data) {
    var userId = data.data!.id;
    log("User ID IS ==========> $userId");
    appData.write(kKeyAccessToken, data.data?.token);
    appData.write(kKeyIsLoggedIn, true);
    appData.write(kKeyUserId, userId);

    // String token = appData.read(kKeyAccessToken);
    DioSingleton.instance.update(data.data!.token!);

    dataFetcher.sink.add(data);
    return data;
  }

  /// Handles a failed OTP verification by recording the backend error message.
  ///
  /// For any [DioException] the backend `message` is stored in [errorMessage].
  /// The [error] is always pushed onto [dataFetcher]; always returns `false`.
  @override
  handleErrorWithReturn(error) {
    if (error is DioException) {
      if (error.response!.statusCode == 400) {
        errorMessage = error.response!.data['message'];
      } else if (error.response!.data['code'] == 403) {
        errorMessage = error.response!.data['message'];
      } else {
        errorMessage = error.response!.data['message'];
      }
    }
    // log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
