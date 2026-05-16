import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for marking a one-to-one chat image as viewed.
///
/// A lazily-created singleton; the reactive [ViewInboxImageRx] wrapper
/// delegates network work here. This is the `mark-viewed` step that
/// triggers the patent reaction flow when a recipient opens a media
/// message.
final class ViewInboxImageApi {
  /// The single shared instance backing [instance].
  static final ViewInboxImageApi _singleton = ViewInboxImageApi._internal();

  /// Private constructor enforcing the singleton pattern.
  ViewInboxImageApi._internal();

  /// The shared [ViewInboxImageApi] instance.
  static ViewInboxImageApi get instance => _singleton;

  /// Reports that the inbox image/message [id] has been viewed.
  ///
  /// Returns the decoded JSON response body as a [Map] on HTTP 200 or
  /// 201. Throws the default [DataSource] failure for any other status,
  /// and rethrows any transport error raised by the Dio client.
  Future<Map> viewInboxImage({required int id}) async {
    try {
      Response response = await postHttp(EndPoints.viewInboxImage(id));
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
