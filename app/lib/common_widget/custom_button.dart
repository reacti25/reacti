import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback onTap;
  final String btnName;
  final double? height;
  final double? width;
  final double? borderRadius;
  final String? icon;
  final double? fontSize;
  const CustomButton({
    super.key,
    required this.onTap,
    required this.btnName,
    this.height,
    this.width,
    this.icon,
    this.borderRadius,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.maxFinite,
      height: height ?? 45.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(borderRadius ?? 8.r),
          ),
          backgroundColor: AppColors.allPrimaryColor,
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
                fontSize: fontSize ?? 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
