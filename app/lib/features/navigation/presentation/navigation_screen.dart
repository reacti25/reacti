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

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    ChatScreen(),
    // Text("Chat"),
    FriendsTabScreen(),
    NewChatScreen(),
    // NotificationScreen(),
    RequestScreen(),
    ProfileScreen(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

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

  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
  }) {
    final bool isSelected = selectedIndex == index;
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
