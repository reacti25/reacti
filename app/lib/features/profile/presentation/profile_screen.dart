import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/profile/model/profile_response.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../chat/presentation/full_screen_image_viewer.dart';
import '../../demo/presentation/demo_reacti_screen.dart';
import '../../invite/data/invite_service.dart';
import '../../invite/presentation/connect_inviter_screen.dart';
import '../../../networks/api_access.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
import 'package:reacti_app/features/navigation/presentation/navigation_screen.dart';

/// Screen that renders the signed-in user's own profile.
///
/// Shows the avatar, name, bio and friend/group counts, plus account and
/// privacy action cards (edit profile, change password, block list, etc.)
/// and the log-out and delete-account actions.
class ProfileScreen extends StatefulWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// State for [ProfileScreen]; builds the UI from the profile stream.
class _ProfileScreenState extends State<ProfileScreen> {
  /// Prompts for an invite link/code, then opens the connect screen (Feature 5
  /// manual-entry fallback until a deep-link provider auto-carries the code).
  Future<void> _promptInviteCode(BuildContext context) async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Have an invite?'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Paste invite link or code',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    if (input == null) return;
    final code = InviteService.instance.codeFromInput(input);
    if (!context.mounted) return;

    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That doesn't look like a valid invite.")),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ConnectInviterScreen(code: code)));
  }

  /// Builds the gradient-backed, scrollable profile layout.
  ///
  /// The body subscribes to `getProfileRx.getProfileStream`: it shows a
  /// spinner while loading, the full profile once data arrives, and an empty
  /// box otherwise.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.maxFinite,
        height: double.maxFinite,
        decoration: BoxDecoration(
          // Keep the branded dark gradient in dark; use the flat canvas in
          // light so Profile matches the rest of the light theme.
          gradient:
              Theme.of(context).brightness == Brightness.dark
                  ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3D441A), Colors.black],
                  )
                  : null,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? null
                  : context.reacti.canvas,
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
                              GestureDetector(
                                // Tap the avatar to enlarge it; no-op when
                                // there's no photo to show.
                                onTap:
                                    (data?.avatar ?? "").isEmpty
                                        ? null
                                        : () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => FullScreenImageViewer(
                                                  url: data!.avatar!,
                                                ),
                                          ),
                                        ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.reacti.brandAccent,
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
                              ),
                              UIHelper.verticalSpace(12.h),
                              Text(
                                data?.fullName ?? "",
                                style: TextFontStyle
                                    .headline20w600CFFFFFFPoppins
                                    .copyWith(
                                      color: context.reacti.textPrimary,
                                    ),
                              ),
                              UIHelper.verticalSpace(6.h),
                              Text(
                                "${data?.username}",
                                style: TextFontStyle
                                    .headline16w400CCCCCCCPoppins
                                    .copyWith(
                                      color: context.reacti.textSecondary,
                                    ),
                              ),
                              UIHelper.verticalSpace(6.h),
                              Text(
                                data?.bio ?? "",
                                style: TextFontStyle
                                    .headline16w400CCCCCCCPoppins
                                    .copyWith(
                                      color: context.reacti.textSecondary,
                                    ),
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
                                    style: TextFontStyle
                                        .headline20w600CFFFFFFPoppins
                                        .copyWith(
                                          color: context.reacti.textPrimary,
                                        ),
                                  ),
                                  Text(
                                    "Friends",
                                    style: TextFontStyle
                                        .headline16w400CCCCCCCPoppins
                                        .copyWith(
                                          color: context.reacti.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    "${data?.totalGroups ?? 0}",
                                    style: TextFontStyle
                                        .headline20w600CFFFFFFPoppins
                                        .copyWith(
                                          color: context.reacti.textPrimary,
                                        ),
                                  ),
                                  Text(
                                    "Groups",
                                    style: TextFontStyle
                                        .headline16w400CCCCCCCPoppins
                                        .copyWith(
                                          color: context.reacti.textSecondary,
                                        ),
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
                              .copyWith(color: context.reacti.textSecondary),
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

                        // Re-runs the local practice ("demo") Reacti on demand —
                        // the only way back in once it has auto-fired once.
                        ProfileCardWidget(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DemoReactiScreen(),
                              ),
                            );
                          },
                          title: 'Try a demo Reacti',
                          materialIcon: Icons.camera_outlined,
                        ),
                        UIHelper.verticalSpace(16.h),

                        // Replays the whole walkthrough. Resets every tour
                        // flag first, so the two just-in-time marks re-arm and
                        // fire again on the next visit to Contacts and to a
                        // chat — replaying only the home marks would show a
                        // third of it. The marks live on the Chat tab, so
                        // switch there before starting: showcasing a target
                        // that is not on screen would show nothing.
                        ProfileCardWidget(
                          onTap: () {
                            FirstRunTour.resetAll();
                            NavigationScreen.goToTab?.call(0);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FirstRunTour.start(force: true);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Walkthrough restarted — the Contacts and '
                                  'chat tips will show again too.',
                                ),
                              ),
                            );
                          },
                          title: 'Replay walkthrough',
                          materialIcon: Icons.map_outlined,
                        ),
                        UIHelper.verticalSpace(16.h),

                        // Manual "who invited you?" entry (Feature 5). The v1
                        // fallback until a deferred-deep-link provider auto-
                        // carries the code through a fresh install (D4).
                        ProfileCardWidget(
                          onTap: () => _promptInviteCode(context),
                          title: 'Connect with an inviter',
                          materialIcon: Icons.link,
                        ),
                        UIHelper.verticalSpace(16.h),

                        ProfileCardWidget(
                          onTap: () {
                            NavigationService.navigateTo(Routes.settingsRoute);
                          },
                          title: 'Settings',
                          materialIcon: Icons.settings,
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

/// A single tappable settings row on the profile screen.
///
/// Renders a leading circular SVG [icon], a [title] label and a trailing
/// chevron, used for actions such as "Edit Profile" or "Change Password".
class ProfileCardWidget extends StatelessWidget {
  /// Invoked when the card is tapped.
  final VoidCallback onTap;

  /// The label shown for this action.
  final String title;

  /// Asset path of the leading SVG icon (used when [materialIcon] is null).
  final String? icon;

  /// A Material icon shown in the leading circle instead of an SVG [icon].
  final IconData? materialIcon;

  /// Creates a profile action card. Provide either an SVG [icon] or a
  /// [materialIcon] for the leading circle.
  const ProfileCardWidget({
    super.key,
    required this.onTap,
    required this.title,
    this.icon,
    this.materialIcon,
  }) : assert(
         icon != null || materialIcon != null,
         'Provide icon or materialIcon',
       );

  /// Builds the tappable card row.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          color: context.reacti.card,
          boxShadow: context.reacti.cardShadow,
        ),
        child: Row(
          spacing: 12.w,
          children: [
            Container(
              padding: EdgeInsets.all(8.sp),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Keep the dark olive tint in dark; a neutral fill in light.
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.c32371B
                        : context.reacti.surfaceVariant,
              ),
              // The icons are lime — invisible on the light grey circle. Tint
              // them to the darkened brand accent in light; native (lime) in
              // dark. Material icons follow the same rule.
              child:
                  materialIcon != null
                      ? Icon(
                        materialIcon,
                        size: 22.sp,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? context.reacti.brandAccent
                                : context.reacti.brandFill,
                      )
                      : SvgPicture.asset(
                        icon!,
                        colorFilter:
                            Theme.of(context).brightness == Brightness.light
                                ? ColorFilter.mode(
                                  context.reacti.brandAccent,
                                  BlendMode.srcIn,
                                )
                                : null,
                      ),
            ),
            Expanded(
              child: Text(
                title,
                style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                  fontSize: 18.sp,
                  color: context.reacti.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: context.reacti.textTertiary,
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
