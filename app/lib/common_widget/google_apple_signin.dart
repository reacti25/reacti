import 'dart:developer';

import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

/// Social sign-in section showing Google and Apple login buttons.
///
/// Renders an "Or Sign In With" divider followed by circular Google and
/// Apple icon buttons. Reused on the login and sign-up screens. The tap
/// handlers currently only log; OAuth wiring is not yet implemented.
class GoogleAppleSignin extends StatelessWidget {
  /// Creates the [GoogleAppleSignin] social login section.
  const GoogleAppleSignin({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80.w,
              child: Divider(color: AppColors.c666666, thickness: 1),
            ),
            UIHelper.horizontalSpace(6.w),
            Text(
              "Or Sign In With",
              style: TextFontStyle.headline10w400CF7F7F7Poppins,
            ),
            UIHelper.horizontalSpace(6.w),
            SizedBox(
              width: 80.w,
              child: Divider(color: AppColors.c666666, thickness: 1),
            ),
          ],
        ),

        UIHelper.verticalSpace(16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                log("Google Sign in");
              },
              child: Container(
                padding: EdgeInsets.all(6.sp),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cFFFFFF,
                ),
                child: SvgPicture.asset(
                  Assets.icons.googleLogo,
                  width: 22.w,
                  height: 22.h,
                ),
              ),
            ),

            UIHelper.horizontalSpace(8.w),

            GestureDetector(
              onTap: () {
                log("Apple Sign in");
              },
              child: Container(
                padding: EdgeInsets.all(6.sp),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cFFFFFF,
                ),
                child: SvgPicture.asset(
                  Assets.icons.appleLogo,
                  width: 22.w,
                  height: 22.h,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
