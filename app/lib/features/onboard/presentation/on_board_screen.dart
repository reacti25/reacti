import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// First-run onboarding screen presenting the app's value proposition.
///
/// Shows a swipeable carousel of intro slides; finishing it records that
/// onboarding is complete and routes the user to the login screen.
class OnBoardScreen extends StatefulWidget {
  /// Creates the onboarding screen.
  const OnBoardScreen({super.key});

  @override
  State<OnBoardScreen> createState() => _OnBoardScreenState();
}

/// State for [OnBoardScreen]; tracks the current page and builds the carousel.
class _OnBoardScreenState extends State<OnBoardScreen> {
  /// Controls and observes the onboarding [PageView].
  final PageController _pageController = PageController();

  /// Index of the currently visible onboarding slide.
  int _currentPage = 0;

  /// The onboarding slides, each a map of image/title/subtitle/description.
  final List<Map<String, String>> onBoardList = [
    {
      'image': Assets.images.onBoardImage1.path,
      'title': 'Share Authentic Moments',
      'subTitle': 'Privacy-first messaging',
      'description':
          'Connect with friends through genuine reactions to the moments that matter most.',
    },
    {
      'image': Assets.images.onBoardImage2.path,
      'title': 'Your Privacy Matters',
      'subTitle': 'Friend-only network',
      'description':
          'Only your approved friends can see your content. No algorithms, no strangers.',
    },
    {
      'image': Assets.images.onBoardImage3.path,
      'title': 'Reaction to View',
      'subTitle': 'Unique experience',
      'description':
          'Record your authentic reaction to unlock and view shared photos and videos.',
    },
  ];

  /// Builds the scaffold: a slide [PageView], a page indicator and the
  /// Skip/Next ("Get Started" on the last slide) buttons.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Adjust background color
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onBoardList.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.asset(onBoardList[index]['image']!),
                        ),
                        UIHelper.verticalSpace(36.h),
                        Text(
                          onBoardList[index]['title']!,
                          style: TextFontStyle.headline20w600CFFFFFFPoppins
                              .copyWith(fontSize: 22.sp),
                          textAlign: TextAlign.center,
                        ),
                        UIHelper.verticalSpace(8.h),
                        Text(
                          onBoardList[index]['subTitle']!,
                          style: TextFontStyle.headline14w500CFFFFFFPoppins
                              .copyWith(
                                fontSize: 16.sp,
                                color: AppColors.allPrimaryColor,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        UIHelper.verticalSpace(10.h),
                        Text(
                          onBoardList[index]['description']!,
                          textAlign: TextAlign.center,
                          style: TextFontStyle.headline14w400C666666Poppins
                              .copyWith(color: AppColors.cFFFFFF),
                        ),
                      ],
                    );
                  },
                ),
              ),
              UIHelper.verticalSpace(20.h),

              // ✅ Smooth Page Indicator
              SmoothPageIndicator(
                controller: _pageController,
                count: onBoardList.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 8.h,
                  dotWidth: 8.w,
                  activeDotColor: AppColors.allPrimaryColor,
                  dotColor: Colors.white24,
                ),
              ),

              UIHelper.verticalSpace(30.h),

              // ✅ Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _pageController.jumpToPage(onBoardList.length - 1);
                    },
                    child: Text(
                      "Skip",
                      style: TextFontStyle.headline14w500CFFFFFFPoppins
                          .copyWith(color: Colors.grey[400]),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.allPrimaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 10.h,
                      ),
                    ),
                    onPressed: () {
                      if (_currentPage == onBoardList.length - 1) {
                        // Last slide → the first-run appearance step, which
                        // records onboarding complete and routes to login.
                        NavigationService.navigateTo(
                          Routes.appearanceOnboardingRoute,
                        );
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(
                      _currentPage == onBoardList.length - 1
                          ? "Get Started"
                          : "Next",
                      style: TextFontStyle.headline14w500CFFFFFFPoppins
                          .copyWith(color: AppColors.c000000),
                    ),
                  ),
                ],
              ),
              UIHelper.verticalSpace(20.h),
            ],
          ),
        ),
      ),
    );
  }
}
