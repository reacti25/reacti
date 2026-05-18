import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// HTTP data source for updating an existing group's profile.
///
/// Implemented as a lazy singleton so callers share one API instance.
/// Not `final` so a test can supply a fake via `implements EditGroupApi`.
class EditGroupApi {
  /// The single shared instance backing [instance].
  static final EditGroupApi _singleton = EditGroupApi._internal();

  /// Private constructor that enforces the singleton pattern.
  EditGroupApi._internal();

  /// The shared [EditGroupApi] instance.
  static EditGroupApi get instance => _singleton;

  /// Updates the group [groupId] with a new [name] and optional [description].
  ///
  /// The request is sent as multipart [FormData]; when [avatar] is supplied
  /// and the file exists on disk it is attached as the `avatar` part so the
  /// group picture can be replaced. Returns the decoded JSON body on success
  /// (HTTP 200). Any non-200 status throws the default failure from
  /// [DataSource]; transport errors are rethrown unchanged.
  Future<Map> editGroup({
    required int groupId,
    required String name,
    String? description,
    XFile? avatar,
  }) async {
    try {
      FormData data = FormData.fromMap({
        "name": name,
        "description": description,
      });

      // Only attach the avatar when a file was picked and still exists.
      if (avatar != null && await File(avatar.path).exists()) {
        data.files.add(
          MapEntry('avatar', await MultipartFile.fromFile(avatar.path)),
        );
      }

      Response response = await postHttp(EndPoints.editGroup(groupId), data);

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
