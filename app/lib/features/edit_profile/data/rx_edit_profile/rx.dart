import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../networks/rx_base.dart';
import '../../../../constants/app_constants.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/stream_cleaner.dart';
import 'api.dart';

final class EditProfileRx extends RxResponseInt<Map> {
  final api = EditProfileApi.instance;

  EditProfileRx({required super.empty, required super.dataFetcher});

  ValueStream get getFileData => dataFetcher.stream;

  Future<bool> userEditProfile({
    required String fName,
    required String lName,
    XFile? avatar,
    String? phone,
    String? bio,
  }) async {
    try {
      final data = await api.userEditProfile(
        fName: fName,
        lName: lName,
        avatar: avatar,
        phone: phone,
        bio: bio,
      );
      handleSuccessWithReturn(data);
      return true;
    } catch (error) {
      return handleErrorWithReturn(error);
    }
  }

  @override
  handleErrorWithReturn(dynamic error) {
    if (error is DioException) {
      if (error.response!.statusCode == 401) {
        totalDataClean();
        appData.write(kKeyIsLoggedIn, false);
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      } else {
        log(error.response!.data["message"]);
      }
    }
    log(error.toString());
    dataFetcher.sink.addError(error);
    return false;
  }
}
