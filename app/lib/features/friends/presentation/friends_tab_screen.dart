import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/friends/presentation/find_screen.dart';
import 'package:reacti_app/features/friends/presentation/friends_screen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../networks/api_access.dart';

/// The top-level Friends tab, hosting a search bar and a two-tab layout for
/// the friend list and device contacts.
///
/// The tabs embed [FriendsScreen] and [FindScreen]; tapping the search field
/// routes to the user-search screen.
class FriendsTabScreen extends StatefulWidget {
  /// Creates the Friends tab screen.
  const FriendsTabScreen({super.key});

  @override
  State<FriendsTabScreen> createState() => _FriendsScreenState();
}

/// State for [FriendsTabScreen]; owns the [TabController] and kicks off the
/// initial friend-list fetch and contact preload.
class _FriendsScreenState extends State<FriendsTabScreen>
    with SingleTickerProviderStateMixin {
  /// Controller driving the two-tab layout (Friends / Contacts).
  late TabController _tabController;

  /// Fetches the friend list and initializes the tab controller when the
  /// screen is first created.
  ///
  /// Contacts permission is intentionally NOT requested here — [FindScreen]
  /// primes the user and only asks the OS for permission when they tap
  /// "Find friends", so opening this tab never fires the contacts dialog.
  @override
  void initState() {
    super.initState();
    apiCall();
    _tabController = TabController(length: 2, vsync: this);
  }

  /// Triggers the friend-list fetch so [FriendsScreen] has data to show.
  void apiCall() {
    getFriendListRx.getFriendList();
  }

  /// Releases the [_tabController] when the screen is removed.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Builds the scaffold: a search bar in the app bar plus the tab bar and
  /// its [FriendsScreen] / [FindScreen] tab views.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onTap: () {
            NavigationService.navigateTo(Routes.searchRoute);
          },
          child: Container(
            height: 40.h,
            padding: EdgeInsets.only(left: 12.w),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.allPrimaryColor, width: 1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: AbsorbPointer(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Search user..',
                  hintStyle: TextFontStyle.headline14w400C666666Poppins
                      .copyWith(color: AppColors.allPrimaryColor),
                  suffixIcon: Icon(
                    Icons.search,
                    color: AppColors.allPrimaryColor,
                  ),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: AppColors.allPrimaryColor),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(15.r),
        child: Column(
          children: [
            Container(
              height: 51.h,
              decoration: BoxDecoration(
                color: AppColors.c252529,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorPadding: EdgeInsets.all(10.r),
                indicator: BoxDecoration(
                  color: AppColors.allPrimaryColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.c333333,
                unselectedLabelColor: AppColors.cFFFFFF,
                labelStyle: TextFontStyle.headline16w500C333333Poppins,
                tabs: [
                  Tab(text: 'Friends'),
                  // Tab(text: 'Requests'),
                  Tab(text: 'Contacts'),
                ],
              ),
            ),
            UIHelper.verticalSpace(16.h),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [FriendsScreen(), FindScreen()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
