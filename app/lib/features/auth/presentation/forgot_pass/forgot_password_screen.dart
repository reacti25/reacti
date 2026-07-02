import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/common_widget/custom_form_field.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../networks/api_access.dart';

/// First step of the password-reset flow: collects the user's email so the
/// backend can send a verification OTP.
///
/// Renders the app logo and a single email field. On a valid "Send Code"
/// submission it calls [forgetPassRx] and, on success, routes to the OTP
/// verification screen, passing the entered email as an argument.
class ForgotPasswordScreen extends StatefulWidget {
  /// Creates the forgot-password screen.
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

/// Mutable state for [ForgotPasswordScreen]; owns the email controller and key.
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// Controller for the email input field.
  final _emailController = TextEditingController();

  /// Key used to validate the email [Form].
  final _formKey = GlobalKey<FormState>();

  /// Disposes the email controller to release its resources.
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Builds the email form and the "Send Code" submit button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppColors.c000000,
      appBar: AppBar(
        title: Text(
          "Forgot Password",
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
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
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  "Email",
                  style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
                    color: context.reacti.textPrimary,
                  ),
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
                        .waitingForSuccess()
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

  /// Builds the email field, validated as non-empty and matching [emailRegex].
  ///
  /// Submitting the field routes directly to the OTP verification screen with
  /// the entered email.
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
