// ignore_for_file: deprecated_member_use

import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../constants/text_font_style.dart';

/// Static utility for showing app-styled snackbar toasts via GetX.
///
/// Provides consistent error and success banners so call sites do not
/// re-style `Get.snackbar` individually.
final class ToastUtil {
  /// Private constructor — this class is a static-only utility.
  ToastUtil._();

  /// Shows a top-anchored warning snackbar carrying [message].
  ///
  /// Used to surface validation and request failures to the user.
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

  /// Shows a top-anchored success snackbar carrying [message].
  ///
  /// Styled with the app's primary colour to confirm a completed action.
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
