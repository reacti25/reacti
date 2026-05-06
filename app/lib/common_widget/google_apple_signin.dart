import 'dart:developer';

import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class GoogleAppleSignin extends StatelessWidget {
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
