import 'dart:developer';

import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../../../common_widget/custom_button.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/api_access.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email, token;
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassController = TextEditingController();
  final _passController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _newPassController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log("Token is ======> ${widget.email}");
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Reset Password",
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),

      body: Consumer<AuthProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: InkWell(
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    UIHelper.verticalSpace(24.h),
                    SvgPicture.asset(Assets.icons.appLogo, height: 120.h),
                    UIHelper.verticalSpace(36.h),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Reset Password",
                        style: TextFontStyle.headline16w400CFFFFFFPoppins,
                      ),
                    ),
                    UIHelper.verticalSpace(16.h),
                    _newPassWidget(provider),
                    UIHelper.verticalSpace(16.h),
                    _confNewPassWidget(provider),
                    UIHelper.verticalSpace(36.h),
                    CustomButton(
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          resetPasswordRx
                              .resetPassword(
                                email: widget.email,
                                token: widget.token,
                                password: _passController.text.trim(),
                                confPass: _newPassController.text.trim(),
                              )
                              .waitingForSucess()
                              .then((success) {
                                if (success) {
                                  ToastUtil.showSuccessMessage(
                                    "Password Reset Successfully.",
                                  );
                                  NavigationService.navigateToReplacementUntil(
                                    Routes.loginScreen,
                                  );
                                }
                              });
                        }
                      },
                      btnName: 'Save Changes',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _newPassWidget(AuthProvider provider) {
    return CustomFormField(
      hintText: "New password",
      controller: _passController,
      textInputAction: TextInputAction.next,
      isPass: true,
      isObsecure: provider.isResetNewPassVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Write your new pasword";
        }
        if (value.length < 8) {
          return "Minimum password length is 8";
        }
        return null;
      },
      suffixIcon: GestureDetector(
        onTap: () {
          provider.toggleResetNewPass();
        },
        child: Icon(
          color: AppColors.allPrimaryColor,
          provider.isResetNewPassVisible
              ? Icons.visibility
              : Icons.visibility_off,
        ),
      ),
    );
  }

  Widget _confNewPassWidget(AuthProvider provider) {
    return CustomFormField(
      hintText: "Confirm new password",
      controller: _newPassController,
      textInputAction: TextInputAction.done,
      isPass: true,
      isObsecure: provider.isResetConfNewPassVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Write your new pasword";
        }
        if (value != _passController.text) {
          return "Password and confirm password should be same.";
        }
        return null;
      },
      suffixIcon: GestureDetector(
        onTap: () {
          provider.toggleResetConfNewPass();
        },
        child: Icon(
          color: AppColors.allPrimaryColor,
          provider.isResetConfNewPassVisible
              ? Icons.visibility
              : Icons.visibility_off,
        ),
      ),
      onFieldSubmitted: (value) {
        if (_formKey.currentState!.validate()) {
          resetPasswordRx
              .resetPassword(
                email: widget.email,
                token: widget.token,
                password: _passController.text.trim(),
                confPass: _newPassController.text.trim(),
              )
              .waitingForSucess()
              .then((success) {
                if (success) {
                  ToastUtil.showSuccessMessage("Password Reset Successfully.");
                  NavigationService.navigateToReplacementUntil(
                    Routes.loginScreen,
                  );
                }
              });
        }
      },
    );
  }
}
