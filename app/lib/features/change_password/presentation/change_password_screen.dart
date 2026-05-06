import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:achiar_expert_app/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../gen/colors.gen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Change Password",
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          physics: BouncingScrollPhysics(),
          child: Consumer<AuthProvider>(
            builder: (context, provider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UIHelper.verticalSpace(20.h),
                  Text(
                    "Old Password",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(12.h),
                  CustomFormField(
                    hintText: "Enter Old Password",
                    controller: _oldPassController,
                    isPass: true,
                    // isPass: true,
                    isObsecure: provider.isOldPassVisible,
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a valid Password';
                      } else if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    suffixIcon: GestureDetector(
                      onTap: () {
                        provider.toggleOldPassVisiable();
                      },
                      child: Icon(
                        color: AppColors.allPrimaryColor,
                        provider.isOldPassVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        //Icons.visibility, color: AppColors.c003F5F,
                      ),
                    ),
                  ),
                  UIHelper.verticalSpace(16.h),
                  Text(
                    "New Password",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(12.h),
                  CustomFormField(
                    hintText: "Enter New Password",
                    controller: _newPassController,
                    isPass: true,
                    // isPass: true,
                    isObsecure: provider.isNewPassVisible,
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a valid Password';
                      } else if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    suffixIcon: GestureDetector(
                      onTap: () {
                        provider.toggleNewPassVisiable();
                      },
                      child: Icon(
                        color: AppColors.allPrimaryColor,
                        provider.isNewPassVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        //Icons.visibility, color: AppColors.c003F5F,
                      ),
                    ),
                  ),

                  UIHelper.verticalSpace(16.h),
                  Text(
                    "Confirm New Password",
                    style: TextFontStyle.headline16w400CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(12.h),
                  CustomFormField(
                    hintText: "Confirm New Password",
                    controller: _confirmPassController,
                    isPass: true,
                    isObsecure: provider.isConfirmPassVisible,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Confirm Password';
                      }
                      if (value != _newPassController.text) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                    suffixIcon: GestureDetector(
                      onTap: () {
                        provider.toggleConfirmPassVisiable();
                      },
                      child: Icon(
                        color: AppColors.allPrimaryColor,
                        provider.isConfirmPassVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        // Icons.visibility, color: AppColors.c003F5F,
                      ),
                    ),
                  ),

                  UIHelper.verticalSpace(24.h),
                  CustomButton(
                    onTap: () {
                      if (_formKey.currentState!.validate()) {
                        changePasswordRx
                            .changePassword(
                              oldPass: _oldPassController.text.trim(),
                              newPass: _newPassController.text.trim(),
                              confNewPass: _confirmPassController.text.trim(),
                            )
                            .waitingForSucess()
                            .then((success) {
                              if (success) {
                                ToastUtil.showSuccessMessage(
                                  "Password Updated",
                                );
                                NavigationService.goBack;
                              }
                            });
                      }
                    },
                    btnName: "Change Password",
                    borderRadius: 10.r,
                  ),
                  UIHelper.verticalSpace(24.h),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
