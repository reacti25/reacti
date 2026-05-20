import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/helpers_method.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/provider/auth_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../../../networks/api_access.dart';

/// Account-registration screen of the auth flow.
///
/// Renders a form collecting first/last name, email, phone and password, plus
/// a terms-and-conditions checkbox. On a valid submission it calls [signupRx]
/// and, on success, routes to the signup OTP-verification screen, passing the
/// entered email as an argument.
class SignupScreen extends StatefulWidget {
  /// Creates the signup screen.
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

/// Mutable state for [SignupScreen]; owns the form controllers and key.
class _SignupScreenState extends State<SignupScreen> {
  /// Controller for the first-name input field.
  final _fNameController = TextEditingController();

  /// Controller for the last-name input field.
  final _lNameController = TextEditingController();

  /// Controller for the email input field.
  final _emailController = TextEditingController();

  /// Controller for the phone-number input field.
  final _phoneController = TextEditingController();

  /// Controller for the password input field.
  final _passController = TextEditingController();

  /// Controller for the confirm-password input field.
  final _confPassController = TextEditingController();

  /// Key used to validate the signup [Form].
  final _formKey = GlobalKey<FormState>();

  /// Disposes the text controllers to release their resources.
  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    _confPassController.dispose();
    super.dispose();
  }

  /// Builds the scrollable registration form wrapped in an [AuthProvider]
  /// consumer.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Registration",
          style: TextFontStyle.headline20w600CFFFFFFPoppins,
        ),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Consumer<AuthProvider>(
          builder: (context, provider, child) {
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  UIHelper.verticalSpace(24.h),
                  SvgPicture.asset(Assets.icons.appLogo, height: 120.h),
                  UIHelper.verticalSpace(16.h),

                  Text(
                    "Register",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(6.h),
                  Text(
                    "Sign up or login to continue",
                    style: TextFontStyle.headline12w400CDDDDDDPoppins,
                  ),
                  UIHelper.verticalSpace(36.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      "First Name",
                      style: TextFontStyle.headline16w400CFFFFFFPoppins,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),
                  _firstNameSection(),

                  UIHelper.verticalSpace(16.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      "Last Name",
                      style: TextFontStyle.headline16w400CFFFFFFPoppins,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),
                  _lastNameSection(),

                  UIHelper.verticalSpace(16.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      "Email",
                      style: TextFontStyle.headline16w400CFFFFFFPoppins,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),
                  _emailSection(),
                  UIHelper.verticalSpace(16.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      "Phone",
                      style: TextFontStyle.headline16w400CFFFFFFPoppins,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),
                  _phoneSection(),
                  UIHelper.verticalSpace(16.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      "Password",
                      style: TextFontStyle.headline16w400CFFFFFFPoppins,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),
                  _passwordWidget(provider),

                  UIHelper.verticalSpace(16.h),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      "Confirm Password",
                      style: TextFontStyle.headline16w400CFFFFFFPoppins,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),
                  _confPassWidget(provider),

                  UIHelper.verticalSpace(16.h),
                  _termsAndPrivacyAcceptSection(provider),
                  UIHelper.verticalSpace(25.h),

                  CustomButton(
                    onTap: () {
                      if (_formKey.currentState!.validate()) {
                        if (!provider.isAccept) {
                          ToastUtil.showErrorMessage(
                            "You must accept the terms and conditions to proceed.",
                          );
                          return;
                        }

                        signupRx
                            .signup(
                              fName: _fNameController.text.trim(),
                              lName: _lNameController.text.trim(),
                              email: _emailController.text.trim(),
                              phone: _phoneController.text.trim(),
                              password: _passController.text.trim(),
                              confPassword: _confPassController.text.trim(),
                            )
                            .waitingForSuccess()
                            .then((success) {
                              if (success) {
                                NavigationService.navigateToWithArgs(
                                  Routes.signupVerifyOtpRoute,
                                  {'email': _emailController.text.trim()},
                                );
                              }
                            });
                      }
                    },
                    btnName: "Sign Up",
                  ),
                  UIHelper.verticalSpace(16.h),

                  // GoogleAppleSignin(),
                  UIHelper.verticalSpace(16.h),

                  _noAccountWidget(),

                  UIHelper.verticalSpace(32.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the first-name field, validated as non-empty.
  CustomFormField _firstNameSection() {
    return CustomFormField(
      hintText: "First Name",
      controller: _fNameController,
      textInputAction: TextInputAction.next,
      inputType: TextInputType.name,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "First name required";
        }

        return null;
      },
    );
  }

  /// Builds the last-name field, validated as non-empty.
  CustomFormField _lastNameSection() {
    return CustomFormField(
      hintText: "Last Name",
      controller: _lNameController,
      textInputAction: TextInputAction.next,
      inputType: TextInputType.name,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Last name required";
        }
        return null;
      },
    );
  }

  /// Builds the email field, validated as non-empty and matching [emailRegex].
  CustomFormField _emailSection() {
    return CustomFormField(
      hintText: "Email Address",
      controller: _emailController,
      textInputAction: TextInputAction.next,
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
    );
  }

  /// Builds the phone-number field (no validation; phone is optional).
  Widget _phoneSection() {
    return CustomFormField(
      hintText: "Phone Number",
      controller: _phoneController,
      textInputAction: TextInputAction.next,
      inputType: TextInputType.phone,
    );
  }

  /// Builds the password field.
  ///
  /// [provider] supplies the obscure-text toggle state. Validates that the
  /// password is non-empty and at least 8 characters.
  Widget _passwordWidget(AuthProvider provider) {
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
  /// value is non-empty and matches the password field; submitting it triggers
  /// the same signup call as the Sign Up button.
  Widget _confPassWidget(AuthProvider provider) {
    return CustomFormField(
      hintText: "Confirm new password",
      controller: _confPassController,
      textInputAction: TextInputAction.done,
      isPass: true,
      isObsecure: provider.isResetConfNewPassVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Write your new password";
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
          provider.isResetConfNewPassVisible
              ? Icons.visibility
              : Icons.visibility_off,
        ),
      ),
      onFieldSubmitted: (value) {
        if (_formKey.currentState!.validate()) {
          if (!provider.isAccept) {
            ToastUtil.showErrorMessage(
              "You must accept the terms and conditions to proceed.",
            );
            return;
          }

          signupRx
              .signup(
                fName: _fNameController.text.trim(),
                lName: _lNameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                password: _passController.text.trim(),
                confPassword: _confPassController.text.trim(),
              )
              .waitingForSuccess()
              .then((success) {
                if (success) {
                  NavigationService.navigateToWithArgs(
                    Routes.signupVerifyOtpRoute,
                    {'email': _emailController.text.trim()},
                  );
                }
              });
        }
      },
    );
  }

  /// Builds the terms-and-conditions checkbox row.
  ///
  /// [provider] holds the acceptance flag; tapping the row or checkbox toggles
  /// it, and the "Terms & Conditions" link routes to the terms screen.
  InkWell _termsAndPrivacyAcceptSection(AuthProvider provider) {
    return InkWell(
      onTap: () {
        provider.toggleIsAccept();
      },
      child: Row(
        spacing: 12.w,
        children: [
          SizedBox(
            height: 20.h,
            width: 20.h,
            // color: Colors.red,
            child: Checkbox(
              checkColor: Colors.black,
              side: BorderSide(color: AppColors.allPrimaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.r),
              ),
              value: provider.isAccept,
              onChanged: (value) {
                provider.toggleIsAccept();
              },
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "I agree with ",
                  style: TextFontStyle.headline12w400CFFFFFFPoppins,
                ),
                TextSpan(
                  text: "Terms & Conditions",
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    color: AppColors.allPrimaryColor,
                  ),
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () {
                          NavigationService.navigateTo(Routes.termsRoute);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "Already have an account? Sign in" rich-text link that routes
  /// to the login screen.
  Widget _noAccountWidget() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "Already have an account? ",
            style: TextFontStyle.headline12w400CFFFFFFPoppins,
          ),
          TextSpan(
            text: "Sign in",
            style: TextFontStyle.headline12w600CDCFC53Poppins,
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    NavigationService.navigateTo(Routes.loginScreen);
                  },
          ),
        ],
      ),
    );
  }
}
