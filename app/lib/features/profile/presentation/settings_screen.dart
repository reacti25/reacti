import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
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

  /// Staging builds pass `--dart-define=ANALYTICS_ENV=staging`; used to gate a
  /// debug-only push-token readout that never appears in production.
  static const bool _isStaging =
      String.fromEnvironment('ANALYTICS_ENV') == 'staging';

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

              if (_isStaging) ...[
                _section(context, 'DEBUG (staging)'),
                ProfileCardWidget(
                  title: 'Push Token',
                  icon: Assets.icons.privacyIcon,
                  onTap: () => _showPushToken(context),
                ),
              ],

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

  /// Staging-only diagnostic: shows this device's FCM push token (or a clear
  /// "no token" message) so it can be copied and used to send a direct test
  /// push while wiring up staging notifications.
  void _showPushToken(BuildContext context) {
    final token = appData.read(kKeyFCMToken) as String?;
    final hasToken = token != null && token.isNotEmpty;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Push token (staging)'),
            content: SelectableText(
              hasToken ? token : 'NO TOKEN — the app has no push token yet.',
            ),
            actions: [
              if (hasToken)
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ToastUtil.showSuccessMessage('Copied');
                  },
                  child: const Text('Copy'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
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
