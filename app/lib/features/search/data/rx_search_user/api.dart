import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';
import '../../model/all_user_response.dart';

/// HTTP data source for searching users by name or username.
///
/// Implemented as a lazy singleton so the search query is served by one
/// shared instance throughout the app.
///
/// Not `final` so a test can supply a fake via `implements SearchApi`.
class SearchApi {
  /// The single shared instance backing [instance].
  static final SearchApi _singleton = SearchApi._internal();

  /// Private constructor enforcing the singleton pattern.
  SearchApi._internal();

  /// The shared [SearchApi] instance used by callers.
  static SearchApi get instance => _singleton;

  /// Searches users matching the [search] term.
  ///
  /// Pass [mode] `'username'` to restrict discovery to username matches (an
  /// empty [search] then returns no results). Returns the parsed
  /// [AllUserResponse] on an HTTP 200; throws the default [DataSource] failure
  /// on any other status, and rethrows transport or parsing errors.
  Future<AllUserResponse> searchUser({
    required String search,
    String? mode,
  }) async {
    try {
      Map data = {'search': search};
      Response response = await getHttp(
        EndPoints.searchUser(search, mode: mode),
        data,
      );
      if (response.statusCode == 200) {
        final data = AllUserResponse.fromRawJson(json.encode(response.data));
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
