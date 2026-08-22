import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

/// The single pre-login screen: one line about what Reacti is, and a way in.
///
/// Replaces the three-slide onboarding carousel
/// (docs/PLAN-onboarding-walkthrough-2026-08-15.md, T4). The carousel
/// explained the product in words, over stock art, before the user had an
/// account — while the Demo Reacti now *shows* the same thing on the other
/// side of signup, and the coach-mark tour teaches the mechanics. Three
/// explanations of one app is two too many.
///
/// The headline is the line already proven on the web invite landing
/// (`/i/{code}`), so the pitch someone reads before installing matches the
/// first thing they see after.
class WelcomeScreen extends StatelessWidget {
  /// Creates the welcome screen.
  ///
  /// When [fromLogin] is true it was pushed from the login screen as a
  /// re-readable explainer, so Continue simply pops instead of consuming the
  /// first-run flag.
  const WelcomeScreen({super.key, this.fromLogin = false});

  /// Whether this was opened from login rather than as first-run.
  final bool fromLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              const Spacer(),
              SvgPicture.asset(
                Theme.of(context).brightness == Brightness.light
                    ? Assets.icons.appLogoLight
                    : Assets.icons.appLogo,
                height: 120.h,
              ),
              UIHelper.verticalSpace(32.h),
              Text(
                "See a friend's real reaction the moment they open your photo.",
                textAlign: TextAlign.center,
                style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
                  fontSize: 24.sp,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.allPrimaryColor,
                    foregroundColor: AppColors.c000000,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  onPressed: () {
                    if (fromLogin) {
                      Navigator.of(context).pop();
                      return;
                    }
                    // First run is over the moment they choose to continue.
                    appData.write(kKeyIsFirstTime, false);
                    NavigationService.navigateToReplacementUntil(
                      Routes.loginScreen,
                    );
                  },
                  child: Text(
                    fromLogin ? "Got it" : "Get started",
                    style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
                      color: AppColors.c000000,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
              UIHelper.verticalSpace(32.h),
            ],
          ),
        ),
      ),
    );
  }
}
