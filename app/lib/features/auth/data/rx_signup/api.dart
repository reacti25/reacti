import 'dart:convert';

import 'package:dio/dio.dart';

import '/networks/endpoints.dart';
import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for the account-registration step.
///
/// Wraps the `POST` call that creates a new user account; the backend then
/// sends a verification OTP that must be confirmed via [SignUpVerifyApi].
/// Implemented as a lazy singleton so callers share one instance.
/// Not `final` so a test can supply a fake via `implements SignUpApi`.
class SignUpApi {
  /// The single shared [SignUpApi] instance.
  static final SignUpApi _singleton = SignUpApi._internal();

  /// Private constructor backing the singleton; prevents external creation.
  SignUpApi._internal();

  /// The lazily-created shared [SignUpApi] instance.
  static SignUpApi get instance => _singleton;

  /// Registers a new user account.
  ///
  /// [fName] and [lName] are the user's first/last name, [email] and [phone]
  /// their contact details, [dateOfBirth] their birthdate as `yyyy-MM-dd`
  /// (the backend's age gate rejects anything under the minimum age), and
  /// [password]/[confPassword] the chosen password and its confirmation.
  /// Returns the decoded response map on HTTP 200. Throws the default
  /// [DataSource] failure for any other status code and rethrows transport
  /// errors.
  Future<Map> signup({
    required String fName,
    required String lName,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String password,
    required String confPassword,
  }) async {
    try {
      Map data = {
        "first_name": fName,
        "last_name": lName,
        "email": email,
        "phone": phone,
        "date_of_birth": dateOfBirth,
        "password": password,
        "password_confirmation": confPassword,
      };

      Response response = await postHttp(EndPoints.signup(), data);

      if (response.statusCode == 200) {
        final data = json.decode(json.encode(response.data));
        return data;
      } else {
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (error) {
      rethrow;
    }
  }
}
