import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

/// Thin HTTP wrapper for updating the signed-in user's profile.
///
/// Implemented as a lazy singleton since it holds no per-call state.
final class EditProfileApi {
  /// The single shared instance, created lazily on first access.
  static final EditProfileApi _singleton = EditProfileApi._internal();

  /// Private constructor used to enforce the singleton pattern.
  EditProfileApi._internal();

  /// The shared [EditProfileApi] instance.
  static EditProfileApi get instance => _singleton;

  /// Submits a profile update as multipart form data.
  ///
  /// [fName] and [lName] are the required first and last names; [phone] and
  /// [bio] are optional text fields. When [avatar] is provided and the file
  /// still exists on disk it is attached as a multipart file upload.
  ///
  /// Returns the decoded JSON body as a [Map] on HTTP 200, throws the
  /// default [DataSource] failure for any other status code, and rethrows
  /// transport-level errors.
  Future<Map> userEditProfile({
    required String fName,
    required String lName,
    XFile? avatar,
    String? phone,
    String? bio,
  }) async {
    try {
      // Note: the [bio] value is sent under the backend's `dob` field key.
      FormData data = FormData.fromMap({
        "first_name": fName,
        "last_name": lName,
        'phone': phone,
        'dob': bio,
      });

      if (avatar != null && await File(avatar.path).exists()) {
        data.files.add(
          MapEntry('avatar', await MultipartFile.fromFile(avatar.path)),
        );
      }

      Response response = await postHttp(EndPoints.editProfile(), data);

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
