import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../gen/colors.gen.dart';

/// The app's shared styled text input field.
///
/// Wraps a [TextFormField] with the project's outlined-border styling,
/// hint/label theming and validation behaviour, so every form across the
/// app uses a consistent input. Reused for auth, profile and chat inputs.
final class CustomFormField extends StatelessWidget {
  /// Placeholder text shown when the field is empty.
  final String? hintText;

  /// Optional font size for [hintText].
  final double? hintFontSize;

  /// Optional floating label text.
  final String? labelText;

  /// Controller backing the field's text value.
  final TextEditingController? controller;

  /// Keyboard type to present for this field.
  final TextInputType? inputType;

  /// Optional fixed field height (currently informational; not applied).
  final double? fieldHeight;

  /// Maximum number of visible lines; defaults to 1.
  final int? maxline;

  /// Minimum number of visible lines; defaults to 1.
  final int? minLine;

  /// Validation callback returning an error string, or `null` when valid.
  final String? Function(String?)? validator;

  /// When `true`, validation runs always; otherwise only on user interaction.
  final bool? validation;

  /// Optional widget placed at the trailing edge of the field.
  final Widget? suffixIcon;

  /// Optional widget placed at the leading edge of the field.
  final Widget? prefixIcon;

  /// Whether the obscured text is currently hidden (used with [isPass]).
  final bool isObsecure;

  /// Whether this field is a password field eligible for obscuring.
  final bool isPass;

  /// Optional focus node controlling this field's focus.
  final FocusNode? focusNode;

  /// Keyboard action button behaviour; defaults to [TextInputAction.next].
  final TextInputAction? textInputAction;

  /// Callback invoked when the field is submitted from the keyboard.
  final Function(String)? onFieldSubmitted;

  /// Callback invoked on every change to the field's text.
  final Function(String)? onChanged;

  /// Optional input formatters applied to typed text.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional text style for the label.
  final TextStyle? labelStyle;

  /// Optional text style for the entered text.
  final TextStyle? style;

  /// Whether the field is enabled for input.
  final bool? isEnabled;

  /// Optional cursor height; defaults to a screen-scaled 20.
  final double? cursorHeight;

  /// Optional colour used for the disabled state.
  final Color? disableColor;

  /// When `true`, the field is read-only (focusable but not editable).
  final bool isRead;

  /// Optional border corner radius; defaults to a screen-scaled 6.
  final double? borderRadius;

  /// Optional outer padding around the field.
  final EdgeInsetsGeometry? padding;

  /// Optional border colour for the enabled state.
  final Color? enableBorderColor;

  /// Optional border colour for the focused state.
  final Color? focusBorderColor;

  /// Optional background fill colour for the field.
  final Color? fillColor;

  /// Creates a [CustomFormField] with the given styling and behaviour.
  const CustomFormField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.inputType,
    this.fieldHeight,
    this.maxline,
    this.validator,
    this.validation = false,
    this.suffixIcon,
    this.prefixIcon,
    this.isObsecure = false,
    this.isPass = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.labelStyle,
    this.isEnabled,
    this.style,
    this.cursorHeight,
    this.disableColor,
    this.isRead = false,
    this.borderRadius,
    this.padding,
    this.hintFontSize,
    this.enableBorderColor,
    this.focusBorderColor,
    this.fillColor,
    this.minLine,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? EdgeInsets.zero,
      child: TextFormField(
        readOnly: isRead,
        cursorHeight: cursorHeight ?? 20.h,
        cursorColor: context.reacti.brandAccent,
        focusNode: focusNode,
        obscureText: isPass ? isObsecure : false,
        textInputAction: textInputAction,
        autovalidateMode:
            validation!
                ? AutovalidateMode.always
                : AutovalidateMode.onUserInteraction,
        validator: validator,
        maxLines: maxline ?? 1,
        minLines: minLine ?? 1,
        controller: controller,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        enabled: isEnabled,
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor ?? context.reacti.surfaceVariant,
          isDense: true,
          suffixIcon: suffixIcon,
          prefixIcon:
              prefixIcon != null
                  ? Padding(padding: EdgeInsets.all(12.sp), child: prefixIcon)
                  : null,
          hintText: hintText,
          hintStyle: TextFontStyle.headline14w400C666666Poppins.copyWith(
            fontSize: hintFontSize ?? 14.sp,
            color: context.reacti.textTertiary,
          ),
          labelText: labelText,
          errorStyle: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            // color: AppColors.cD12E34,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 6.r),
            borderSide: BorderSide(color: AppColors.cE5E5E5, width: 1.w),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 6.r),
            borderSide: BorderSide(
              color: focusBorderColor ?? AppColors.cE5E5E5,
              width: 1.w,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 6.r),
            borderSide: const BorderSide(
              // color: disableColor ?? AppColors.c6D6D6D.withOpacity(0.19),
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 6.r),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 6.r),
            // Light: a clearly-visible outline so the field reads as a bounded
            // box on the canvas (the old cE5E5E5 blended into it). Dark keeps
            // its original faint light border.
            borderSide: BorderSide(
              color:
                  enableBorderColor ??
                  (isDark ? AppColors.cE5E5E5 : context.reacti.outline),
              width: isDark ? 0.5.w : 1.w,
            ),
          ),
        ),
        style:
            style ??
            TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
              color: context.reacti.textPrimary,
            ),
        keyboardType: inputType,
      ),
    );
  }
}
