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

  /// Live text of the contacts search, owned here because the field sits in the
  /// app bar — above both tabs — while the list it filters lives in
  /// [FindScreen].
  final TextEditingController _contactQuery = TextEditingController();

  /// Whether the Contacts tab is the visible one.
  ///
  /// The two tabs search different things: Friends opens the server-side user
  /// search, Contacts filters the phonebook already on the device. Same bar,
  /// two jobs, so it has to know where it is.
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
      if (!_onContacts) _contactQuery.clear();
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
    _contactQuery.dispose();
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
        title:
            _onContacts
                // Contacts are already on the device — filter them in place
                // rather than sending the user to the server-side user search,
                // which cannot see their phonebook at all.
                ? ContactsSearchField(
                  controller: _contactQuery,
                  onChanged: (_) => setState(() {}),
                )
                : GestureDetector(
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
                children: [
                  const FriendsScreen(),
                  FindScreen(query: _contactQuery.text),
                ],
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

/// The editable "Search contact.." bar shown on the Contacts tab.
///
/// Shares the bordered frame of [FriendsSearchBox], and like it takes care NOT
/// to let the field draw a second one: `border: InputBorder.none` alone does
/// not do that, because it leaves the theme's `enabledBorder` in place. Every
/// border state is suppressed explicitly, and `isDense` + zero content padding
/// keep the text on the same baseline as the tappable variant.
class ContactsSearchField extends StatelessWidget {
  /// Creates the contacts search field.
  const ContactsSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

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
            hintText: 'Search contact..',
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
