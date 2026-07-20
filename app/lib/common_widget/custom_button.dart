import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

/// A filled primary-action button with optional leading SVG icon.
///
/// Renders an [ElevatedButton] in the app's primary colour with a centred
/// label, sized to fill its parent's width by default. Reused as the main
/// call-to-action across forms and screens.
class CustomButton extends StatelessWidget {
  /// Callback invoked when the button is pressed.
  ///
  /// When `null` the button renders in the disabled/greyed state (the
  /// [ElevatedButton] default), so callers can grey it out in place.
  final VoidCallback? onTap;

  /// The text label displayed inside the button.
  final String btnName;

  /// Optional fixed button height; defaults to a screen-scaled 45.
  final double? height;

  /// Optional fixed button width; defaults to filling available width.
  final double? width;

  /// Optional corner radius; defaults to a screen-scaled 8.
  final double? borderRadius;

  /// Optional asset path for an SVG icon shown before the label.
  final String? icon;

  /// Optional label font size; defaults to a screen-scaled 14.
  final double? fontSize;

  /// Creates a [CustomButton] with the given label and tap handler.
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
