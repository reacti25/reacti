import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:reacti_app/theme/app_theme.dart';

import 'profile_screen.dart' show ProfileCardWidget;

/// The dedicated settings screen reached from the profile tab.
///
/// Groups the app's preferences by intent — Account, Privacy, Appearance,
/// About & Data — with the sign-out and delete-account actions isolated at the
/// bottom. Each row reuses an existing sub-screen; this screen only organises
/// the entry points.
class SettingsScreen extends StatelessWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextFontStyle.headline18w400CFFFFFFPoppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(context, 'ACCOUNT'),
              ProfileCardWidget(
                title: 'Change Password',
                icon: Assets.icons.passwordIcon,
                onTap:
                    () => NavigationService.navigateTo(
                      Routes.changePasswordRoute,
                    ),
              ),

              _section(context, 'PRIVACY'),
              ProfileCardWidget(
                title: 'Read Receipts',
                icon: Assets.icons.privacyIcon,
                onTap:
                    () =>
                        NavigationService.navigateTo(Routes.readReceiptsRoute),
              ),
              UIHelper.verticalSpace(12.h),
              ProfileCardWidget(
                title: 'Blocked Users',
                icon: Assets.icons.blockIcon,
                onTap: () => NavigationService.navigateTo(Routes.blockRoute),
              ),
              UIHelper.verticalSpace(12.h),
              ProfileCardWidget(
                title: 'Permissions',
                icon: Assets.icons.passwordIcon,
                onTap:
                    () => NavigationService.navigateTo(Routes.permissionRoute),
              ),

              _section(context, 'APPEARANCE'),
              ProfileCardWidget(
                title: 'Appearance',
                icon: Assets.icons.privacyIcon,
                onTap:
                    () => NavigationService.navigateTo(Routes.appearanceRoute),
              ),

              _section(context, 'SOUNDS & HAPTICS'),
              const _HapticsToggle(),

              _section(context, 'ABOUT & DATA'),
              ProfileCardWidget(
                title: 'Usage Data',
                icon: Assets.icons.privacyIcon,
                onTap:
                    () => NavigationService.navigateTo(
                      Routes.analyticsSettingsRoute,
                    ),
              ),
              UIHelper.verticalSpace(12.h),
              ProfileCardWidget(
                title: 'Privacy Policy',
                icon: Assets.icons.privacyIcon,
                onTap: () => NavigationService.navigateTo(Routes.privacyRoute),
              ),

              UIHelper.verticalSpace(32.h),
              CustomButton(
                onTap: () => _logout(),
                btnName: 'Log Out',
                borderRadius: 10.r,
              ),
              UIHelper.verticalSpace(16.h),
              _deleteAccountButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// A grouped-section label with the spacing used above each group.
  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(top: 24.h, bottom: 12.h),
      child: Text(
        title,
        style: TextFontStyle.headline18w400CFFFFFFPoppins.copyWith(
          color: context.reacti.textSecondary,
        ),
      ),
    );
  }

  void _logout() {
    logoutRx.userLogout().waitingForSuccess().then((success) {
      if (success) {
        ToastUtil.showSuccessMessage('Logout Successful');
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      }
    });
  }

  /// The bordered "Delete Account" action that opens a confirm sheet.
  Widget _deleteAccountButton(BuildContext context) {
    return InkWell(
      onTap: () => _confirmDelete(context),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        width: double.maxFinite,
        decoration: BoxDecoration(
          border: Border.all(width: 1.w, color: context.reacti.brandFill),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          'Delete Account',
          style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
            color: context.reacti.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (sheetContext) => Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            decoration: BoxDecoration(
              color: sheetContext.reacti.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Are you sure you want to delete your account?',
                  style: TextFontStyle.headline18w400CFFFFFFPoppins.copyWith(
                    color: sheetContext.reacti.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                UIHelper.verticalSpace(12.h),
                Text(
                  'Once you delete your account, there is no going back. '
                  'Please be certain.',
                  style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                    color: sheetContext.reacti.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                UIHelper.verticalSpace(12.h),
                Row(
                  spacing: 12.w,
                  children: [
                    Expanded(
                      child: CustomButton(
                        onTap: () {
                          NavigationService.goBack;
                          _deleteAccount();
                        },
                        btnName: 'Delete',
                        borderRadius: 10.r,
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => NavigationService.goBack,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          width: double.maxFinite,
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 1.w,
                              color: sheetContext.reacti.brandFill,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextFontStyle.headline16w500CFFFFFFPoppins
                                .copyWith(
                                  color: sheetContext.reacti.textPrimary,
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
  }

  void _deleteAccount() {
    deleteAccountRx.deleteAccount().waitingForSuccess().then((success) {
      if (success) {
        ToastUtil.showSuccessMessage('Account Deleted Successfully');
        NavigationService.navigateToReplacementUntil(Routes.loginScreen);
      }
    });
  }
}

/// Local-only toggle for chat send/receive haptics. Self-contained (owns its
/// switch state and persistence) so the settings list can stay stateless.
class _HapticsToggle extends StatefulWidget {
  const _HapticsToggle();

  @override
  State<_HapticsToggle> createState() => _HapticsToggleState();
}

class _HapticsToggleState extends State<_HapticsToggle> {
  /// Current value; seeded from storage, defaulting to on.
  late bool _enabled = appData.read(kKeySoundHapticsEnabled) != false;

  void _onChanged(bool value) {
    setState(() => _enabled = value);
    appData.write(kKeySoundHapticsEnabled, value);
    FeedbackService.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      key: const Key('haptics_switch'),
      value: _enabled,
      onChanged: _onChanged,
      contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
      title: Text(
        'Sounds & haptics',
        style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
          color: scheme.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 6.h),
        child: Text(
          'Vibrate when you send and receive messages.',
          style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
