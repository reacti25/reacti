import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

/// A secondary-action button with a primary-colour outline.
///
/// Renders an [ElevatedButton] with a dark fill and a coloured border, used
/// as the lower-emphasis counterpart to [CustomButton]. Supports an optional
/// leading SVG icon.
class CustomOutlineButton extends StatelessWidget {
  /// Callback invoked when the button is pressed.
  final VoidCallback onTap;

  /// The text label displayed inside the button.
  final String btnName;

  /// Optional fixed button height; defaults to a screen-scaled 45.
  final double? height;

  /// Optional fixed button width; defaults to filling available width.
  final double? width;

  /// Optional corner radius; defaults to a screen-scaled 6.
  final double? borderRadius;

  /// Optional asset path for an SVG icon shown before the label.
  final String? icon;

  /// Creates a [CustomOutlineButton] with the given label and tap handler.
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
