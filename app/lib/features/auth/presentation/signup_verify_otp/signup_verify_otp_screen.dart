import 'dart:developer';

import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinput/pinput.dart';

import '../../../../common_widget/custom_button.dart';
import '../../../../constants/text_font_style.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../gen/colors.gen.dart';
import '../../../../helpers/all_routes.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../helpers/ui_helpers.dart';
import '../../../../networks/api_access.dart';

class SignupVerifyOtpScreen extends StatefulWidget {
  final String email;
  const SignupVerifyOtpScreen({super.key, required this.email});

  @override
  State<SignupVerifyOtpScreen> createState() => _SignupVerifyOtpScreenState();
}

class _SignupVerifyOtpScreenState extends State<SignupVerifyOtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
                    verifySignupOtpRx
                        .verifySignupOtp(
                          otp: _otpController.text.trim(),
                          email: widget.email,
                        )
                        .waitingForSucess()
                        .then((success) {
                          if (success) {
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
