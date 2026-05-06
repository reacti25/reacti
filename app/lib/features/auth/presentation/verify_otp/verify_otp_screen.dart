import 'dart:developer';

import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinput/pinput.dart';
import 'package:slide_countdown/slide_countdown.dart';

import '../../../../networks/api_access.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int seconds = 60;
  Key countdownKey = UniqueKey();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppColors.scaffoldColor,
      appBar: AppBar(
        title: Text(
          "Verify OTP",
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
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
              SvgPicture.asset(Assets.icons.appLogo, height: 120.h),
              UIHelper.verticalSpace(36.h),
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Verification Code",
                  style: TextFontStyle.headline16w400CFFFFFFPoppins,
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
                        .waitingForSucess()
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

  Widget _expiredTextWidget() {
    return seconds == 0
        ? TextButton(
          onPressed: () {
            _otpController.clear();
            resendForgetOtpRx
                .resendForgetOtp(email: widget.email)
                .waitingForSucess()
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
              color: AppColors.allPrimaryColor,
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
                color: AppColors.cFFFFFF,
              ),
            ),
            SlideCountdown(
              key: countdownKey,
              duration: Duration(seconds: seconds),
              decoration: BoxDecoration(color: Colors.transparent),
              style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                color: AppColors.allPrimaryColor,
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
                color: AppColors.allPrimaryColor,
              ),
            ),
          ],
        );
  }

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
        textStyle: TextFontStyle.headline16w400CFFFFFFPoppins,
        decoration: BoxDecoration(
          color: Colors.transparent, // color for empty cells
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            width: 1.w,
            color: AppColors.cE5E5E5, // Default border color
          ),
        ),
      ),
      submittedPinTheme: PinTheme(
        width: 50.w,
        height: 45.h,
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        textStyle: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
          color: AppColors.allPrimaryColor, // change text color if you want
        ),
        decoration: BoxDecoration(
          color: Colors.transparent, // color for filled cells
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(width: 1.w, color: AppColors.allPrimaryColor),
        ),
      ),

      //
      onCompleted: (pin) => log('Completed: $pin'),
      onChanged: (value) => log('Changed: $value'),
    );
  }
}
