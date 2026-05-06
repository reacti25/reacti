import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../networks/api_access.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                        style: TextFontStyle.headline16w500CFFFFFFPoppins,
                      ),
                      UIHelper.verticalSpace(6.h),
                      Text(
                        "Login to continue",
                        style: TextFontStyle.headline12w400CDDDDDDPoppins,
                      ),
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
                                .waitingForSucess()
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

  Widget _noAccountWidget() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "Don't have an account? ",
            style: TextFontStyle.headline12w400CFFFFFFPoppins,
          ),
          TextSpan(
            text: "Sign up",
            style: TextFontStyle.headline12w600CDCFC53Poppins,
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

  Widget _forgotPasswordWidget() {
    return GestureDetector(
      onTap: () {
        NavigationService.navigateTo(Routes.forgetPassRoute);
      },
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          "Forgot Password",
          style: TextFontStyle.headline12w400CDCFC53Poppins,
        ),
      ),
    );
  }

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
              .waitingForSucess()
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
