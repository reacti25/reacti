import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/theme/appearance_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// First-run step letting a new user pick the app's appearance before signing
/// in. Shown once at the end of onboarding; the same choice is editable later
/// in Settings › Appearance.
///
/// Tapping a row applies the theme live (via [AppearanceOptions]). "Continue"
/// marks onboarding complete ([kKeyIsFirstTime] = false) and routes to login —
/// so the first-run flag flips only once the whole first-run flow, theme step
/// included, is finished.
class AppearanceOnboardingScreen extends StatelessWidget {
  /// Creates the first-run appearance step.
  const AppearanceOnboardingScreen({super.key});

  /// Records onboarding as complete and replaces the stack with the login flow.
  void _continue() {
    appData.write(kKeyIsFirstTime, false);
    NavigationService.navigateToReplacementUntil(Routes.loginScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UIHelper.verticalSpace(12.h),
              Text(
                'Choose your appearance',
                style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
                  fontSize: 22.sp,
                ),
              ),
              UIHelper.verticalSpace(8.h),
              Text(
                'Pick a look for the app. You can change this anytime in '
                'Settings.',
                style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                  color: AppColors.cCCCCCC,
                ),
              ),
              UIHelper.verticalSpace(24.h),
              const AppearanceOptions(),
              const Spacer(),
              CustomButton(
                onTap: _continue,
                btnName: 'Continue',
                borderRadius: 10.r,
              ),
              UIHelper.verticalSpace(12.h),
            ],
          ),
        ),
      ),
    );
  }
}
