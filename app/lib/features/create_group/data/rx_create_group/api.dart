import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../networks/dio/dio.dart';
import '../../../../../networks/endpoints.dart';
import '../../../../../networks/exception_handler/data_source.dart';

final class CreateGroupApi {
  static final CreateGroupApi _singleton = CreateGroupApi._internal();
  CreateGroupApi._internal();

  static CreateGroupApi get instance => _singleton;

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
