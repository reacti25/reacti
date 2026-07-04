import 'dart:developer';

import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinput/pinput.dart';

import '../../../../common_widget/custom_button.dart';
import '../../../../constants/app_constants.dart';
import '../../../../constants/text_font_style.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/di.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../helpers/ui_helpers.dart';
import '../../../../networks/api_access.dart';

/// OTP-confirmation step that completes account registration.
///
/// Renders a 4-digit OTP input for the code emailed after signup. On a valid
/// "Continue" submission it calls [verifySignupOtpRx] and, on success,
/// replaces the stack with the main navigation screen.
class SignupVerifyOtpScreen extends StatefulWidget {
  /// Email of the account being verified; the OTP was sent to this address.
  final String email;

  /// Creates the signup OTP-verification screen for the given [email].
  const SignupVerifyOtpScreen({super.key, required this.email});

  @override
  State<SignupVerifyOtpScreen> createState() => _SignupVerifyOtpScreenState();
}

/// Mutable state for [SignupVerifyOtpScreen]; owns the OTP controller and key.
class _SignupVerifyOtpScreenState extends State<SignupVerifyOtpScreen> {
  /// Controller for the OTP pin input.
  final _otpController = TextEditingController();

  /// Key used to validate the OTP [Form].
  final _formKey = GlobalKey<FormState>();

  /// Disposes the OTP controller to release its resources.
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// Builds the OTP form and the "Continue" submit button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppColors.scaffoldColor,
      appBar: AppBar(
        title: Text(
          "Verify OTP",
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UIHelper.verticalSpace(24.h),
              SvgPicture.asset(
                Theme.of(context).brightness == Brightness.light
                    ? Assets.icons.appLogoLight
                    : Assets.icons.appLogo,
                height: 120.h,
              ),
              UIHelper.verticalSpace(36.h),
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Verification Code",
                  style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
                    color: context.reacti.textPrimary,
                  ),
                ),
              ),
              UIHelper.verticalSpace(8.h),
              // FUTURE: when paid SMS/WhatsApp OTP channels are added, this line
              // becomes a channel picker (Email vs SMS vs WhatsApp). Email is
              // the free default and only channel today.
              Text(
                "We emailed a 4-digit code to ${maskEmail(widget.email)}",
                textAlign: TextAlign.center,
                style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                  color: context.reacti.textSecondary,
                ),
              ),
              UIHelper.verticalSpace(16.h),
              _otpFieldWidget(),
              UIHelper.verticalSpace(24.h),
              CustomButton(
                onTap: () {
                  if (_formKey.currentState!.validate()) {
                    verifySignupOtpRx
                        .verifySignupOtp(
                          otp: _otpController.text.trim(),
                          email: widget.email,
                        )
                        .waitingForSuccess()
                        .then((success) {
                          if (success) {
                            // Mark this as a fresh sign-up so the first entry to
                            // the app offers the one-time appearance picker.
                            appData.write(kKeyJustSignedUp, true);
                            NavigationService.navigateToReplacementUntil(
                              Routes.navigationScreen,
                            );
                          }
                        });
                  }
                },
                btnName: 'Continue',
              ),
              UIHelper.verticalSpace(36.h),
              UIHelper.verticalSpace(100.h),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the 4-digit [Pinput] OTP field, validated as non-empty.
  Widget _otpFieldWidget() {
    return Pinput(
      controller: _otpController,
      length: 4,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Enter your 4 digit otp code";
        }
        return null;
      },
      defaultPinTheme: PinTheme(
        width: 50.w,
        height: 45.h,
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        textStyle: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
          color: context.reacti.textPrimary,
        ),
        decoration: BoxDecoration(
          // Light: a white cell with a clear outline so the empty boxes read
          // on the canvas. Dark: transparent + hairline (unchanged).
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : context.reacti.card,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            width: 1.w,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? context.reacti.hairline
                    : context.reacti.outline,
          ),
        ),
      ),
      submittedPinTheme: PinTheme(
        width: 50.w,
        height: 45.h,
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        textStyle: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
          color: context.reacti.brandAccent, // change text color if you want
        ),
        decoration: BoxDecoration(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors
                      .transparent // color for filled cells
                  : context.reacti.card,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(width: 1.w, color: context.reacti.brandAccent),
        ),
      ),

      //
      onCompleted: (pin) => log('Completed: $pin'),
      onChanged: (value) => log('Changed: $value'),
    );
  }
}
