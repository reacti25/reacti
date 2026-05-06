import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/profile/model/profile_response.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../helpers/toast.dart';
import '../../../networks/api_access.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.maxFinite,
        height: double.maxFinite,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF3D441A), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: StreamBuilder(
                stream: getProfileRx.getProfileStream,
                builder: (context, asyncSnapshot) {
                  if (asyncSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (asyncSnapshot.hasData) {
                    ProfileResponse response = asyncSnapshot.data;
                    final data = response.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UIHelper.verticalSpace(16.h),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.allPrimaryColor,
                                    width: 2.sp,
                                  ),
                                ),
                                child: ClipOval(
                                  child: CustomNetworkImage(
                                    height: 90.h,
                                    width: 90.w,
                                    urls: data?.avatar ?? "",
                                  ),
                                ),
                              ),
                              UIHelper.verticalSpace(12.h),
                              Text(
                                data?.fullName ?? "",
                                style:
                                    TextFontStyle.headline20w600CFFFFFFPoppins,
                              ),
                              UIHelper.verticalSpace(6.h),
                              Text(
                                "${data?.username}",
                                style:
                                    TextFontStyle.headline16w400CCCCCCCPoppins,
                              ),
                              UIHelper.verticalSpace(6.h),
                              Text(
                                data?.bio ?? "",
                                style:
                                    TextFontStyle.headline16w400CCCCCCCPoppins,
                              ),
                            ],
                          ),
                        ),
                        UIHelper.verticalSpace(20.h),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    "${data?.totalFriends ?? 0}",
                                    style:
                                        TextFontStyle
                                            .headline20w600CFFFFFFPoppins,
                                  ),
                                  Text(
                                    "Friends",
                                    style:
                                        TextFontStyle
                                            .headline16w400CCCCCCCPoppins,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    "${data?.totalGroups ?? 0}",
                                    style:
                                        TextFontStyle
                                            .headline20w600CFFFFFFPoppins,
                                  ),
                                  Text(
                                    "Groups",
                                    style:
                                        TextFontStyle
                                            .headline16w400CCCCCCCPoppins,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        UIHelper.verticalSpace(30.h),
                        Text(
                          "ACCOUNT",
                          style: TextFontStyle.headline18w400CFFFFFFPoppins
                              .copyWith(color: AppColors.cCCCCCC),
                        ),
                        UIHelper.verticalSpace(16.h),

                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(
                              Routes.editProfileRoute,
                            );
                          },
                          title: 'Edit Profile',
                          icon: Assets.icons.profilePersonIcon,
                        ),
                        UIHelper.verticalSpace(16.h),
                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(
                              Routes.sentRequestRoute,
                            );
                          },
                          title: 'Sent Requests',
                          icon: Assets.icons.profilePersonIcon,
                        ),
                        UIHelper.verticalSpace(16.h),

                        Text(
                          "PRIVACY & SECURITY",
                          style: TextFontStyle.headline18w400CFFFFFFPoppins
                              .copyWith(color: AppColors.cCCCCCC),
                        ),
                        UIHelper.verticalSpace(16.h),
                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(Routes.privacyRoute);
                          },
                          title: 'Privacy Policy',
                          icon: Assets.icons.privacyIcon,
                        ),
                        // UIHelper.verticalSpace(16.h),
                        // ProfileCardWidget(
                        //   onTap: () {
                        //     NavigationService.navigateTo(Routes.termsRoute);
                        //   },
                        //   title: 'Terms & Conditions',
                        //   icon: Assets.icons.privacyIcon,
                        // ),
                        UIHelper.verticalSpace(16.h),
                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(
                              Routes.changePasswordRoute,
                            );
                          },
                          title: 'Change Password',
                          icon: Assets.icons.passwordIcon,
                        ),
                        UIHelper.verticalSpace(16.h),
                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(
                              Routes.permissionRoute,
                            );
                          },
                          title: 'Permissions',
                          icon: Assets.icons.passwordIcon,
                        ),
                        UIHelper.verticalSpace(16.h),
                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(Routes.blockRoute);
                          },
                          title: 'Block Users',
                          icon: Assets.icons.blockIcon,
                        ),
                        UIHelper.verticalSpace(16.h),
                        CustomButton(
                          onTap: () {
                            logoutRx.userLogout().waitingForSucess().then((
                              success,
                            ) {
                              if (success) {
                                ToastUtil.showSuccessMessage(
                                  "Logout Successful",
                                );
                                Navigator.pop(NavigationService.context);
                                NavigationService.navigateToReplacementUntil(
                                  Routes.loginScreen,
                                );
                              }
                            });
                          },
                          btnName: "Log Out",
                          borderRadius: 10.r,
                        ),
                        UIHelper.verticalSpace(16.h),

                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16.r),
                                ),
                              ),
                              context: context,
                              builder:
                                  (_) => Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 24.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cFFFFFF,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16.r),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Are you sure you want to delete your account?",
                                          style: TextFontStyle
                                              .headline18w400CFFFFFFPoppins
                                              .copyWith(
                                                color: AppColors.c000000,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),

                                        UIHelper.verticalSpace(12.h),

                                        Text(
                                          "Once you delete your account, there is no going back. Please be certain.",
                                          style:
                                              TextFontStyle
                                                  .headline14w400C666666Poppins,
                                          textAlign: TextAlign.center,
                                        ),

                                        UIHelper.verticalSpace(12.h),

                                        Row(
                                          spacing: 12.w,
                                          children: [
                                            Expanded(
                                              child: CustomButton(
                                                onTap: () {
                                                  Navigator.pop(
                                                    NavigationService.context,
                                                  );
                                                  deleteAccountRx
                                                      .deleteAccount()
                                                      .waitingForSucess()
                                                      .then((success) {
                                                        if (success) {
                                                          ToastUtil.showSuccessMessage(
                                                            "Account Deleted Successfully",
                                                          );
                                                          NavigationService.navigateToReplacementUntil(
                                                            Routes.loginScreen,
                                                          );
                                                        }
                                                      });
                                                },
                                                btnName: "Delete",
                                                borderRadius: 10.r,
                                              ),
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  NavigationService.goBack;
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12.h,
                                                  ),
                                                  width: double.maxFinite,

                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      width: 1.w,
                                                      color:
                                                          AppColors
                                                              .allPrimaryColor,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12.r,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    "Cancel",
                                                    style: TextFontStyle
                                                        .headline16w500CFFFFFFPoppins
                                                        .copyWith(
                                                          color:
                                                              AppColors.c000000,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            width: double.maxFinite,

                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 1.w,
                                color: AppColors.allPrimaryColor,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              "Delete Account",
                              style: TextFontStyle.headline16w500CFFFFFFPoppins,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileCardWidget extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String icon;
  const ProfileCardWidget({
    super.key,
    required this.onTap,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          color: AppColors.c161618,
        ),
        child: Row(
          spacing: 12.w,
          children: [
            Container(
              padding: EdgeInsets.all(8.sp),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.c32371B,
              ),
              child: SvgPicture.asset(icon),
            ),
            Expanded(
              child: Text(
                title,
                style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                  fontSize: 18.sp,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.cFFFFFF,
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
