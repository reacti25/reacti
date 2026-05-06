import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class CustomOutlineButton extends StatelessWidget {
  final VoidCallback onTap;
  final String btnName;
  final double? height;
  final double? width;
  final double? borderRadius;
  final String? icon;
  const CustomOutlineButton({
    super.key,
    required this.onTap,
    required this.btnName,
    this.height,
    this.width,
    this.icon,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.maxFinite,
      height: height ?? 45.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          side: BorderSide(width: 1.w, color: AppColors.allPrimaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(borderRadius ?? 6.r),
          ),
          backgroundColor: AppColors.c000000,
        ),
        onPressed: onTap,
        child: Row(
          spacing: 12.w,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon != null ? SvgPicture.asset(icon!) : SizedBox.shrink(),
            Text(
              btnName,
              style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                color: AppColors.allPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
