import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/chat/presentation/chat_screen.dart';
import 'package:reacti_app/features/friends/presentation/friends_tab_screen.dart';
import 'package:reacti_app/features/profile/presentation/profile_screen.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../networks/api_access.dart';
import '../../request/presentation/request_screen.dart';

/// Bottom-navigation shell hosting the app's primary tabs.
///
/// Swaps between the Chat, Friends, Request and Profile screens via a custom
/// [BottomAppBar], and bootstraps the user profile and FCM token on first
/// display. Creating a group is reached from the Chats screen header, not the
/// bottom bar.
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
    FriendsTabScreen(),
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
        // Colour comes from bottomAppBarTheme (black in dark, white in light).
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
              icon: Assets.icons.notification,
              label: "Request",
            ),
            _buildNavItem(
              index: 3,
              icon: Assets.icons.profile,
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single bottom-navigation item, filling its share of the row.
  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
  }) {
    return Expanded(
      child: NavBarItem(
        icon: icon,
        label: label,
        selected: selectedIndex == index,
        onTap: () => onItemTapped(index),
      ),
    );
  }
}

/// A single bottom-navigation item: an icon above a label that switches the
/// active tab on tap.
///
/// In **light** mode the [selected] item is drawn as a filled `brandFill` lime
/// pill (with `onBrandFill` icon/label) so the active tab is unmistakable on the
/// near-white nav. In **dark** mode it is left exactly as before — a tinted
/// icon/label with no pill — so dark stays byte-for-byte identical.
class NavBarItem extends StatelessWidget {
  /// Creates a bottom-navigation item.
  const NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// SVG asset path for the item's icon.
  final String icon;

  /// Caption shown beneath the icon.
  final String label;

  /// Whether this item is the currently active tab.
  final bool selected;

  /// Invoked when the item is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      final reacti = context.reacti;
      final Color fg = selected ? reacti.onBrandFill : reacti.textSecondary;
      return InkWell(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
            decoration: BoxDecoration(
              color: selected ? reacti.brandFill : Colors.transparent,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4.h,
              children: [
                SvgPicture.asset(
                  icon,
                  key: ValueKey(icon + selected.toString()),
                  semanticsLabel: label,
                  colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                ),
                Text(
                  label,
                  style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                    color: fg,
                    fontSize: 12.sp,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6.h,
          children: [
            SvgPicture.asset(
              icon,
              key: ValueKey(icon + selected.toString()),
              semanticsLabel: label,
              colorFilter: ColorFilter.mode(
                selected
                    ? context.reacti.brandAccent
                    : context.reacti.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            Text(
              label,
              style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                color:
                    selected
                        ? context.reacti.brandAccent
                        : context.reacti.textSecondary,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
