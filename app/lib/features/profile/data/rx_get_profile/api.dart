import 'dart:convert';
import 'dart:developer';

import 'package:achiar_expert_app/features/profile/model/profile_response.dart';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for fetching the signed-in user's profile.
///
/// Implemented as a lazy singleton since it holds no per-call state.
final class GetProfileApi {
  /// The single shared instance, created lazily on first access.
  static final GetProfileApi _singleton = GetProfileApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  GetProfileApi._internal();

  /// The shared [GetProfileApi] instance.
  static GetProfileApi get instance => _singleton;

  /// Fetches the current user's profile from the backend.
  ///
  /// Returns a parsed [ProfileResponse] on HTTP 200. Throws the default
  /// [DataSource] failure for any other status code and rethrows
  /// transport-level errors.
  Future<ProfileResponse> getProfile() async {
    try {
      Response response = await getHttp(EndPoints.userProfile());
      if (response.statusCode == 200) {
        final data = ProfileResponse.fromRawJson(json.encode(response.data));
        return data;
      } else {
        log('Error: ${response.statusCode}');
        throw DataSource.DEFAULT.getFailure();
      }
    } catch (e) {
      rethrow;
    }
  }
}
