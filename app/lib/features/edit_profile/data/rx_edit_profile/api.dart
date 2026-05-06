import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class EditProfileApi {
  static final EditProfileApi _singleton = EditProfileApi._internal();
  EditProfileApi._internal();

  static EditProfileApi get instance => _singleton;

  Future<Map> userEditProfile({
    required String fName,
    required String lName,
    XFile? avatar,
    String? phone,
    String? bio,
  }) async {
    try {
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
