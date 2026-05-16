import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/chat/presentation/chat_screen.dart';
import 'package:achiar_expert_app/features/friends/presentation/friends_tab_screen.dart';
import 'package:achiar_expert_app/features/newchat/newchat_screen.dart';
import 'package:achiar_expert_app/features/profile/presentation/profile_screen.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../helpers/all_routes.dart';
import '../../../helpers/navigation_service.dart';
import '../../../networks/api_access.dart';
import '../../request/presentation/request_screen.dart';

/// Bottom-navigation shell hosting the app's primary tabs.
///
/// Swaps between the Chat, Friends, New Chat, Request and Profile screens via
/// a custom [BottomAppBar], and bootstraps the user profile and FCM token on
/// first display.
class NavigationScreen extends StatefulWidget {
  /// Creates the bottom-navigation shell.
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

/// State for [NavigationScreen]; tracks the active tab and builds the shell.
class _NavigationScreenState extends State<NavigationScreen> {
  /// Index of the currently selected bottom-navigation tab.
  int selectedIndex = 0;

  /// The tab screens, indexed to match the bottom-navigation items.
  final List<Widget> pages = const [
    ChatScreen(),
    // Text("Chat"),
    FriendsTabScreen(),
    NewChatScreen(),
    // NotificationScreen(),
    RequestScreen(),
    ProfileScreen(),
  ];

  /// Switches the visible tab to the one at [index].
  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  /// Loads the user profile and registers the device's push token on startup.
  ///
  /// The FCM token is only sent when both a stored device id and token are
  /// available; otherwise registration is skipped until they exist.
  @override
  void initState() {
    getProfileRx.getProfile();

    final deviceId = appData.read(kKeyDeviceID);
    final token = appData.read(kKeyFCMToken);

    if (deviceId != null && token != null) {
      addTokenRx.addToken(deviceId: deviceId, token: token);
    }

    // _requestPermissions();
    super.initState();
  }

  /// Builds the scaffold: the active tab body and the custom bottom nav bar.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: BottomAppBar(
        color: AppColors.c000000,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(index: 0, icon: Assets.icons.chat, label: "Chat"),
            _buildNavItem(
              index: 1,
              icon: Assets.icons.friends,
              label: "Friends",
            ),
            _buildNavItem(
              index: 2,
              icon: Assets.icons.newchat,
              label: "New Chat",
            ),
            _buildNavItem(
              index: 3,
              icon: Assets.icons.notification,
              label: "Request",
            ),
            _buildNavItem(
              index: 4,
              icon: Assets.icons.profile,
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single bottom-navigation item.
  ///
  /// [index] identifies the tab, [icon] is the SVG asset path and [label] is
  /// the caption. The center "New Chat" item ([index] 2) is styled and routed
  /// specially: it opens the create-group route instead of switching tabs and
  /// hides its label. Returns the constructed nav-item widget.
  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
  }) {
    /// Whether this item is the currently active tab.
    final bool isSelected = selectedIndex == index;

    /// Whether this is the special center "New Chat" item.
    final bool isNewChatIcon = index == 2;
    return Expanded(
      child: InkWell(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        onTap: () {
          if (index == 2) {
            NavigationService.navigateTo(Routes.createGroupRoute);
            return;
          }
          onItemTapped(index);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6.h,
            children: [
              SvgPicture.asset(
                icon,
                key: ValueKey(icon + isSelected.toString()),
                semanticsLabel: label,
                colorFilter:
                    isNewChatIcon
                        ? null
                        : isSelected
                        ? const ColorFilter.mode(
                          AppColors.allPrimaryColor,
                          BlendMode.srcIn,
                        )
                        : null,
              ),

              if (!isNewChatIcon) // Only show label if not new chat icon
                Text(
                  label,
                  style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                    color:
                        isSelected
                            ? AppColors.allPrimaryColor
                            : AppColors.cF7F7F7,
                    fontSize: 12.sp,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
