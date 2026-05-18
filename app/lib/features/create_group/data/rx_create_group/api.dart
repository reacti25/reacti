import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for creating a new group.
///
/// Implemented as a lazy singleton so callers share one API instance.
/// Not `final` so a test can supply a fake via `implements CreateGroupApi`.
class CreateGroupApi {
  /// The single shared instance backing [instance].
  static final CreateGroupApi _singleton = CreateGroupApi._internal();

  /// Private constructor that enforces the singleton pattern.
  CreateGroupApi._internal();

  /// The shared [CreateGroupApi] instance.
  static CreateGroupApi get instance => _singleton;

  /// Creates a group named [name] with the given [memberIds].
  ///
  /// The request is sent as multipart [FormData]; [description] is optional
  /// and, when [avatar] is supplied and the file exists on disk, it is
  /// attached as the `avatar` part for the group picture. Returns the decoded
  /// JSON body on success (HTTP 200). Any non-200 status throws the default
  /// failure from [DataSource]; transport errors are rethrown unchanged.
  Future<Map> createGroup({
    required String name,
    String? description,
    required List<int?> memberIds,
    XFile? avatar,
  }) async {
    try {
      FormData data = FormData.fromMap({
        "name": name,
        "description": description,
        "members[]": memberIds,
      });

      // Only attach the avatar when a file was picked and still exists.
      if (avatar != null && await File(avatar.path).exists()) {
        data.files.add(
          MapEntry('avatar', await MultipartFile.fromFile(avatar.path)),
        );
      }

      Response response = await postHttp(EndPoints.createGroup(), data);

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
