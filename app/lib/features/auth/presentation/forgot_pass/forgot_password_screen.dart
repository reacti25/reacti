import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/helpers_method.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../networks/api_access.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppColors.c000000,
      appBar: AppBar(
        title: Text(
          "Forgot Password",
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              UIHelper.verticalSpace(24.h),

              SvgPicture.asset(Assets.icons.appLogo, height: 120.h),
              UIHelper.verticalSpace(36.h),

              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  "Email",
                  style: TextFontStyle.headline16w400CFFFFFFPoppins,
                ),
              ),
              UIHelper.verticalSpace(8.h),
              _emailWidget(),
              UIHelper.verticalSpace(36.h),
              CustomButton(
                onTap: () {
                  if (_formKey.currentState!.validate()) {
                    forgetPassRx
                        .forgetPassword(email: _emailController.text.trim())
                        .waitingForSucess()
                        .then((success) {
                          if (success) {
                            NavigationService.navigateToWithArgs(
                              Routes.verifyOtpRoute,
                              {'email': _emailController.text.trim()},
                            );
                          }
                        });
                  }
                },
                btnName: 'Send Code',
              ),
              UIHelper.verticalSpace(16.h),
              // CustomOutlineButton(
              //   onTap: () {
              //     NavigationService.navigateToReplacementUntil(
              //       Routes.loginScreen,
              //     );
              //   },
              //   btnName: 'Return to Sign In',
              // ),
              // UIHelper.verticalSpace(36.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailWidget() {
    return CustomFormField(
      hintText: "Enter your Mail",
      controller: _emailController,
      textInputAction: TextInputAction.done,
      inputType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Email Required";
        }
        if (!emailRegex.hasMatch(value)) {
          return "Please enter a valid email address";
        }
        return null;
      },
      onFieldSubmitted: (value) {
        if (_formKey.currentState!.validate()) {
          NavigationService.navigateToWithArgs(Routes.verifyOtpRoute, {
            'email': _emailController.text.trim(),
          });
        }
      },
    );
  }
}
