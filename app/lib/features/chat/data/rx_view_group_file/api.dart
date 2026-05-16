import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for marking a group-chat file as viewed.
///
/// A lazily-created singleton; the reactive [ViewGroupFileRx] wrapper
/// delegates network work here. This is the group-chat counterpart of
/// the `mark-viewed` step that triggers the patent reaction flow.
final class ViewGroupFileApi {
  /// The single shared instance backing [instance].
  static final ViewGroupFileApi _singleton = ViewGroupFileApi._internal();

  /// Private constructor enforcing the singleton pattern.
  ViewGroupFileApi._internal();

  /// The shared [ViewGroupFileApi] instance.
  static ViewGroupFileApi get instance => _singleton;

  /// Reports that the group-chat file [id] has been viewed.
  ///
  /// Returns the decoded JSON response body as a [Map] on HTTP 200 or
  /// 201. Throws the default [DataSource] failure for any other status,
  /// and rethrows any transport error raised by the Dio client.
  Future<Map> viewGroupFile({required int id}) async {
    try {
      Response response = await postHttp(EndPoints.viewGroupFile(id));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(json.encode(response.data));
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
