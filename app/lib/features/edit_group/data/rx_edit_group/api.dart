import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class EditGroupApi {
  static final EditGroupApi _singleton = EditGroupApi._internal();
  EditGroupApi._internal();

  static EditGroupApi get instance => _singleton;

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
