import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/common_widget/custom_form_field.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/provider/auth_provider.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../networks/api_access.dart';

/// Entry-point screen of the auth flow: lets a returning user sign in with
/// their email and password.
///
/// Renders the app logo, an email and password form, a forgot-password link
/// and a "Sign up" link. On a valid submission it calls [loginRx] and, on
/// success, replaces the stack with the main navigation screen.
class LoginScreen extends StatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Mutable state for [LoginScreen]; owns the form controllers and key.
class _LoginScreenState extends State<LoginScreen> {
  /// Controller for the email input field.
  final _emailController = TextEditingController();

  /// Controller for the password input field.
  final _passwordController = TextEditingController();

  /// Key used to validate the login [Form].
  final _formKey = GlobalKey<FormState>();

  /// Disposes the text controllers to release their resources.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Builds the scrollable login form wrapped in an [AuthProvider] consumer.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              physics: BouncingScrollPhysics(),
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
                    // spacing: 14.h,
                    children: [
                      UIHelper.verticalSpace(46.5.h),

                      SvgPicture.asset(Assets.icons.appLogo, height: 120.h),
                      UIHelper.verticalSpace(16.h),

                      Text(
                        "Login",
                        style: TextFontStyle.headline16w500CFFFFFFPoppins
                            .copyWith(color: context.reacti.textPrimary),
                      ),
                      UIHelper.verticalSpace(6.h),
                      Text(
                        "Login to continue",
                        style: TextFontStyle.headline12w400CDDDDDDPoppins
                            .copyWith(color: context.reacti.textSecondary),
                      ),
                      UIHelper.verticalSpace(36.h),

                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          "Email",
                          style: TextFontStyle.headline16w400CFFFFFFPoppins
                              .copyWith(color: context.reacti.textPrimary),
                        ),
                      ),
                      UIHelper.verticalSpace(8.h),
                      _emailWidget(),

                      UIHelper.verticalSpace(16.h),

                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          "Password",
                          style: TextFontStyle.headline16w400CFFFFFFPoppins
                              .copyWith(color: context.reacti.textPrimary),
                        ),
                      ),
                      UIHelper.verticalSpace(8.h),
                      _passwordWidget(provider),

                      UIHelper.verticalSpace(16.h),

                      _forgotPasswordWidget(),
                      UIHelper.verticalSpace(16.h),

                      CustomButton(
                        onTap: () {
                          if (_formKey.currentState!.validate()) {
                            loginRx
                                .login(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text.trim(),
                                )
                                .waitingForSuccess()
                                .then((success) {
                                  if (success) {
                                    ToastUtil.showSuccessMessage(
                                      "Login Successful",
                                    );
                                    NavigationService.navigateToReplacementUntil(
                                      Routes.navigationScreen,
                                    );
                                  }
                                });
                          }
                        },
                        btnName: 'Sign In',
                      ),

                      UIHelper.verticalSpace(16.h),

                      // GoogleAppleSignin(),
                      UIHelper.verticalSpace(16.h),
                      _noAccountWidget(),
                      UIHelper.verticalSpace(16.h),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the "Don't have an account? Sign up" rich-text link that routes to
  /// the signup screen.
  Widget _noAccountWidget() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "Don't have an account? ",
            style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
              color: context.reacti.textSecondary,
            ),
          ),
          TextSpan(
            text: "Sign up",
            style: TextFontStyle.headline12w600CDCFC53Poppins.copyWith(
              color: context.reacti.brandAccent,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    NavigationService.navigateTo(Routes.signupScreen);
                  },
          ),
        ],
      ),
    );
  }

  /// Builds the right-aligned "Forgot Password" link that starts the
  /// password-reset flow.
  Widget _forgotPasswordWidget() {
    return GestureDetector(
      onTap: () {
        NavigationService.navigateTo(Routes.forgetPassRoute);
      },
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          "Forgot Password",
          style: TextFontStyle.headline12w400CDCFC53Poppins.copyWith(
            color: context.reacti.brandAccent,
          ),
        ),
      ),
    );
  }

  /// Builds the password field.
  ///
  /// [provider] supplies the obscure-text toggle state. Validates that the
  /// password is non-empty and at least 8 characters; submitting the field
  /// triggers the same login call as the Sign In button.
  Widget _passwordWidget(AuthProvider provider) {
    return CustomFormField(
      hintText: "Password",
      controller: _passwordController,
      textInputAction: TextInputAction.done,
      isPass: true,
      isObsecure: provider.isLoginPassVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Write your password";
        } else if (value.length < 8) {
          return "Minimum password length is 8";
        }
        return null;
      },
      suffixIcon: GestureDetector(
        onTap: () {
          provider.toggleLoginPass();
        },
        child: Icon(
          provider.isLoginPassVisible ? Icons.visibility : Icons.visibility_off,
        ),
      ),
      onFieldSubmitted: (value) {
        if (_formKey.currentState!.validate()) {
          loginRx
              .login(
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
              )
              .waitingForSuccess()
              .then((success) {
                if (success) {
                  ToastUtil.showSuccessMessage("Login Successful");
                  NavigationService.navigateToReplacementUntil(
                    Routes.navigationScreen,
                  );
                }
              });
        }
      },
    );
  }

  /// Builds the email field, validated as non-empty and matching [emailRegex].
  Widget _emailWidget() {
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
}
