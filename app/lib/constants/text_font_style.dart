import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Namespace of reusable [TextStyle] presets for the app's typography.
///
/// Each constant is named by its size, weight, and colour so screens share
/// consistent text styling instead of redefining [TextStyle]s inline. Sizes
/// use `flutter_screenutil`'s `.sp` for responsive scaling.
class TextFontStyle {
  /// Private constructor — this class is never instantiated.
  TextFontStyle._();

  /// 32sp, weight 600, colour `#242424`, Poppins.
  static final headline32w600C242424Poppins = TextStyle(
    color: AppColors.c242424,
    fontSize: 32.sp,
    fontWeight: FontWeight.w600,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 18sp, weight 400, colour `#FFFFFF`, Poppins.
  static final headline18w400CFFFFFFPoppins = TextStyle(
    color: AppColors.cFFFFFF,
    fontSize: 18.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 10sp, weight 400, colour `#F7F7F7`, Poppins.
  static final headline10w400CF7F7F7Poppins = TextStyle(
    color: AppColors.cF7F7F7,
    fontSize: 10.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 16sp, weight 500, colour `#F7F7F7`, Poppins.
  static final headline16w500CF7F7F7Poppins = TextStyle(
    color: AppColors.cF7F7F7,
    fontSize: 16.sp,
    fontWeight: FontWeight.w500,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 12sp, weight 400, colour `#DDDDDD`, Poppins.
  static final headline12w400CDDDDDDPoppins = TextStyle(
    color: AppColors.cDDDDDD,
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 14sp, weight 600, colour `#333333`, Poppins.
  static final headline14w600C333333Poppins = TextStyle(
    color: AppColors.c333333,
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 14sp, weight 400, colour `#666666`, Poppins — used for hint text.
  static final headline14w400C666666Poppins = TextStyle(
    // for hint text
    color: AppColors.c666666,
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 14sp, weight 400, colour `#CCCCCC`, Poppins.
  static final headline14w400CCCCCCCPoppins = TextStyle(
    color: AppColors.cCCCCCC,
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 12sp, weight 400, colour `#FFFFFF`, Poppins.
  static final headline12w400CFFFFFFPoppins = TextStyle(
    color: AppColors.cFFFFFF,
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 16sp, weight 500, colour `#FFFFFF`, Poppins.
  static final headline16w500CFFFFFFPoppins = TextStyle(
    color: AppColors.cFFFFFF,
    fontSize: 16.sp,
    fontWeight: FontWeight.w500,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 14sp, weight 500, colour `#FFFFFF`, Poppins.
  static final headline14w500CFFFFFFPoppins = TextStyle(
    color: AppColors.cFFFFFF,
    fontSize: 14.sp,
    fontWeight: FontWeight.w500,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 16sp, weight 400, colour `#FFFFFF`, Poppins — used for login/password titles.
  static final headline16w400CFFFFFFPoppins = TextStyle(
    //Login/Password title
    color: AppColors.cFFFFFF,
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 16sp, weight 400, colour `#CCCCCC`, Poppins — used for login/password titles.
  static final headline16w400CCCCCCCPoppins = TextStyle(
    //Login/Password title
    color: AppColors.cCCCCCC,
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 12sp, weight 600, colour `#DCFC53` (brand), Poppins.
  static final headline12w600CDCFC53Poppins = TextStyle(
    color: AppColors.cDCFC53,
    fontSize: 12.sp,
    fontWeight: FontWeight.w600,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 12sp, weight 400, colour `#DCFC53` (brand), Poppins.
  static final headline12w400CDCFC53Poppins = TextStyle(
    color: AppColors.cDCFC53,
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 20sp, weight 600, colour `#FFFFFF`, Poppins.
  static final headline20w600CFFFFFFPoppins = TextStyle(
    color: AppColors.cFFFFFF,
    fontSize: 20.sp,
    fontWeight: FontWeight.w600,
    fontFamily: Assets.fonts.poppinsRegular,
  );

  /// 16sp, weight 500, colour `#333333`, Poppins — used for login/password titles.
  static final headline16w500C333333Poppins = TextStyle(
    //Login/Password title
    color: AppColors.c333333,
    fontSize: 16.sp,
    fontWeight: FontWeight.w500,
    fontFamily: Assets.fonts.poppinsRegular,
  );
}
