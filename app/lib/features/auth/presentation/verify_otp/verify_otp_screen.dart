import 'dart:developer';

import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinput/pinput.dart';
import 'package:slide_countdown/slide_countdown.dart';

import '../../../../networks/api_access.dart';

/// OTP-confirmation step of the password-reset flow.
///
/// Renders a 4-digit OTP input for the code emailed during the
/// forgot-password flow, plus a countdown that reveals a "Resend Code" button
/// once it expires. On a valid "Continue" submission it calls
/// [verifyForgetPassRx] and, on success, routes to the reset-password screen,
/// passing the email and the issued reset token.
class VerifyOtpScreen extends StatefulWidget {
  /// Email of the account being recovered; the OTP was sent to this address.
  final String email;

  /// Creates the password-reset OTP-verification screen for the given [email].
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

/// Mutable state for [VerifyOtpScreen]; owns the OTP controller and the
/// resend-countdown state.
class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  /// Controller for the OTP pin input.
  final _otpController = TextEditingController();

  /// Key used to validate the OTP [Form].
  final _formKey = GlobalKey<FormState>();

  /// Remaining seconds before the OTP is considered expired; `0` reveals the
  /// "Resend Code" button.
  int seconds = 60;

  /// Key for the countdown widget so it can be rebuilt/reset when needed.
  Key countdownKey = UniqueKey();

  /// Disposes the OTP controller to release its resources.
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// Builds the OTP form, the "Continue" button and the expiry/resend section.
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
                    verifyForgetPassRx
                        .verifyForgetPass(
                          email: widget.email,
                          otp: _otpController.text.trim(),
                        )
                        .waitingForSuccess()
                        .then((success) {
                          if (success) {
                            NavigationService.navigateToWithArgs(
                              Routes.resetPassScreen,
                              {
                                'email': widget.email,
                                'token': verifyForgetPassRx.resendToken,
                              },
                            );
                          }
                        });
                  }
                },
                btnName: 'Continue',
              ),
              UIHelper.verticalSpace(36.h),
              _expiredTextWidget(),
              UIHelper.verticalSpace(100.h),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the expiry section below the OTP field.
  ///
  /// While [seconds] is non-zero it shows a live [SlideCountdown]; once the
  /// countdown completes [seconds] is set to `0` and a "Resend Code" button is
  /// shown that clears the field and calls [resendForgetOtpRx].
  Widget _expiredTextWidget() {
    return seconds == 0
        ? TextButton(
          onPressed: () {
            _otpController.clear();
            resendForgetOtpRx
                .resendForgetOtp(email: widget.email)
                .waitingForSuccess()
                .then((success) {
                  if (success) {
                    ToastUtil.showSuccessMessage("OTP resend successfully");
                  }
                });
            log("Resend Code");
            // Call your resend code logic here
          },
          child: Text(
            "Resend Code",
            style: TextFontStyle.headline14w600C333333Poppins.copyWith(
              color: context.reacti.brandAccent,
            ),
          ),
        )
        : Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8.w,
          children: [
            Text(
              "This code will expire in",
              style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                color: context.reacti.textSecondary,
              ),
            ),
            SlideCountdown(
              key: countdownKey,
              duration: Duration(seconds: seconds),
              decoration: BoxDecoration(color: Colors.transparent),
              style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                color: context.reacti.brandAccent,
              ),
              onDone: () {
                setState(() {
                  seconds = 0;
                });
              },
            ),
            Text(
              "sec",
              style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                color: context.reacti.brandAccent,
              ),
            ),
          ],
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
