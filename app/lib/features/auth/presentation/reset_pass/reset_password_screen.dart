import 'dart:developer';

import 'package:reacti_app/common_widget/custom_form_field.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../../../common_widget/custom_button.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/api_access.dart';

/// Final step of the password-reset flow: lets the user set a new password
/// after their reset OTP has been verified.
///
/// Renders the app logo and a new-password / confirm-password form. On a valid
/// "Save Changes" submission it calls [resetPasswordRx] with [email] and
/// [token] and, on success, replaces the stack with the login screen.
class ResetPasswordScreen extends StatefulWidget {
  /// Email of the account whose password is being reset, and the reset [token]
  /// issued after OTP verification that authorizes the change.
  final String email, token;

  /// Creates the reset-password screen for the given [email] and reset [token].
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

/// Mutable state for [ResetPasswordScreen]; owns the form controllers and key.
class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /// Controller for the confirm-password input field.
  final _newPassController = TextEditingController();

  /// Controller for the new-password input field.
  final _passController = TextEditingController();

  /// Key used to validate the reset-password [Form].
  final _formKey = GlobalKey<FormState>();

  /// Disposes the text controllers to release their resources.
  @override
  void dispose() {
    _newPassController.dispose();
    _passController.dispose();
    super.dispose();
  }

  /// Builds the reset-password form wrapped in an [AuthProvider] consumer.
  @override
  Widget build(BuildContext context) {
    // Debug trace of which account this screen is resetting.
    log("Token is ======> ${widget.email}");
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Reset Password",
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
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
                        style: TextFontStyle.headline16w400CFFFFFFPoppins
                            .copyWith(color: context.reacti.textPrimary),
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
                              .waitingForSuccess()
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

  /// Builds the new-password field.
  ///
  /// [provider] supplies the obscure-text toggle state. Validates that the
  /// password is non-empty and at least 8 characters.
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
          color: context.reacti.brandAccent,
          provider.isResetNewPassVisible
              ? Icons.visibility
              : Icons.visibility_off,
        ),
      ),
    );
  }

  /// Builds the confirm-password field.
  ///
  /// [provider] supplies the obscure-text toggle state. Validates that the
  /// value is non-empty and matches the new-password field; submitting it
  /// triggers the same reset call as the Save Changes button.
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
          color: context.reacti.brandAccent,
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
              .waitingForSuccess()
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
