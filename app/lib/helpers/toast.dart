// ignore_for_file: deprecated_member_use

import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../constants/text_font_style.dart';

final class ToastUtil {
  ToastUtil._();

  static void showErrorMessage(String message) {
    Get.snackbar(
      titleText: Text(
        "Warning!",
        style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(),
      ),
      messageText: Text(
        message,
        style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
          fontSize: 14.sp,
        ),
      ),
      "",
      message,
      borderRadius: 26.r,
      margin: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: 12.h),
      snackPosition: SnackPosition.TOP,
    );
  }

  static void showSuccessMessage(String message) {
    Get.snackbar(
      titleText: Text(
        "Successful!",
        // style: TextFontStyle.headline16w600CFFFFFFPoppins,
      ),
      messageText: Text(
        message,
        // style: TextFontStyle.headline14w500C242424Poppins.copyWith(
        //   color: AppColors.cFFFFFF,
        // ),
      ),
      "",
      message,
      backgroundColor: AppColors.allPrimaryColor,
      borderRadius: 26.r,
      margin: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: 10.h),
      snackPosition: SnackPosition.TOP,
    );
  }
}
