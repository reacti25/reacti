import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/friends/presentation/find_screen.dart';
import 'package:reacti_app/features/friends/presentation/friends_screen.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
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

  /// Live text of the in-tab search, owned here because the field sits in the
  /// app bar — above both tabs — while the lists it filters live in
  /// [FriendsScreen] and [FindScreen].
  ///
  /// One controller for both tabs, cleared on every switch: the two lists have
  /// nothing to do with each other, and carrying a query across would hide rows
  /// on a tab the user never searched.
  final TextEditingController _localQuery = TextEditingController();

  /// Whether the Contacts tab is the visible one.
  bool get _onContacts => _tabController.index == 1;

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
    // Rebuild on tab change so the bar swaps between the two behaviours, and
    // clear the filter on the way out — coming back to Contacts to find it
    // still narrowed by a search you have forgotten reads as missing contacts.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _localQuery.clear();
      setState(() {});
    });
  }

  /// Triggers the friend-list fetch so [FriendsScreen] has data to show.
  void apiCall() {
    getFriendListRx.getFriendList();
  }

  /// Releases the [_tabController] when the screen is removed.
  @override
  void dispose() {
    _tabController.dispose();
    _localQuery.dispose();
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
        // Both tabs filter a list the app already holds — your friends, your
        // phonebook — so both search in place. Finding people you do NOT know
        // is a different thing with different rules (username prefix, minimum
        // length, capped, rate-limited) and lives behind its own screen.
        title: LocalSearchField(
          controller: _localQuery,
          hintText: _onContacts ? 'Search contact..' : 'Search friend..',
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          // Marked, but with no showOnceKey of its own: it is step two of the
          // empty-Friends sequence, so the empty state drives it. Left to fire
          // by itself it would interrupt whatever tab the user was on.
          TourMark(
            markKey: FirstRunTour.searchUsernameKey,
            title: 'Or search by username',
            description:
                "Know someone's @username? Find them here. They don't have "
                'to be in your contacts.',
            child: IconButton(
              tooltip: 'Find people on Reacti',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => NavigationService.navigateTo(Routes.searchRoute),
            ),
          ),
        ],
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
                children: [
                  FriendsScreen(
                    query: _localQuery.text,
                    // Someone with no friends needs a way to get some, and the
                    // Contacts tab is owned here, not by the list.
                    onFindFromContacts: () => _tabController.animateTo(1),
                  ),
                  FindScreen(query: _localQuery.text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The editable search bar above the Friends / Contacts tabs.
///
/// Takes care NOT to draw a second frame inside its own: `border:
/// InputBorder.none` does not do that on its own, because it leaves the theme's
/// `enabledBorder` in place — which is exactly how this bar ended up with two
/// rounded rectangles on top of each other. Every border state is suppressed
/// explicitly.
class LocalSearchField extends StatelessWidget {
  /// Creates the in-tab search field.
  const LocalSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  /// Placeholder naming what this tab searches — friends or contacts.
  final String hintText;

  /// Holds the live query; owned by the parent so the list can read it.
  final TextEditingController controller;

  /// Called on every keystroke so the filtered list rebuilds as they type.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline, width: 1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: scheme.onSurface, fontSize: 14.sp),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: hintText,
            hintStyle: TextFontStyle.headline14w400C666666Poppins.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            // A visible way out of a filter, so clearing it never means
            // selecting the text and deleting it by hand.
            //
            // Driven off the controller rather than a plain `controller.text`
            // read: this widget must not depend on its parent remembering to
            // rebuild it just to swap its own icon.
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) {
                  return Icon(Icons.search, color: scheme.onSurfaceVariant);
                }
                return GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Icon(Icons.close, color: scheme.onSurfaceVariant),
                );
              },
            ),
            suffixIconConstraints: BoxConstraints(minWidth: 24.w),
          ),
        ),
      ),
    );
  }
}
