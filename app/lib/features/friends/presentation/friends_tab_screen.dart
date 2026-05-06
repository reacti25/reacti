import 'dart:developer';

import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/friends/presentation/find_screen.dart';
import 'package:achiar_expert_app/features/friends/presentation/friends_screen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../networks/api_access.dart';

class FriendsTabScreen extends StatefulWidget {
  const FriendsTabScreen({super.key});

  @override
  State<FriendsTabScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    getContacts();
    apiCall();
    _tabController = TabController(length: 2, vsync: this);
  }

  void apiCall() {
    getFriendListRx.getFriendList();
  }

  Future<List<Contact>> getContacts() async {
    try {
      // Check and request permission
      final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
      if (status != PermissionStatus.granted) {
        throw Exception('Contact permission denied');
      }

      // Fetch all contacts (without thumbnails for better performance)
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      // log("Contacts =====> $contacts");
      return contacts;
    } catch (e) {
      log('Error getting contacts: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
