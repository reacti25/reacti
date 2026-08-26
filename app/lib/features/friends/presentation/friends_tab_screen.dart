import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/friends/presentation/find_screen.dart';
import 'package:reacti_app/features/friends/presentation/friends_screen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onTap: () {
            NavigationService.navigateTo(Routes.searchRoute);
          },
          child: const FriendsSearchBox(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(15.r),
        child: Column(
          children: [
            Container(
              height: 51.h,
              decoration: BoxDecoration(
                color: context.reacti.surfaceVariant,
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
                labelColor: context.reacti.onBrandFill,
                unselectedLabelColor: scheme.onSurface,
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

/// The tappable "Search user.." bar in the Friends app bar.
///
/// Deliberately NOT a [TextField]. It never takes input — the tap opens the
/// search screen — and as a read-only field it drew a second frame inside this
/// one: `border: InputBorder.none` does not override the theme's
/// `enabledBorder`, so the field's own outline sat on top of the container's.
/// A [Row] has no border to suppress.
class FriendsSearchBox extends StatelessWidget {
  /// Creates the search bar.
  const FriendsSearchBox({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40.h,
      padding: EdgeInsets.only(left: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline, width: 1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Search user..',
              style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: Icon(Icons.search, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
