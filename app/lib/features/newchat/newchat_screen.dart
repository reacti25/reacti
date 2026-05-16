import 'dart:developer';

import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/newchat/model/newchat_model.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

/// Screen for starting a new conversation.
///
/// Offers shortcuts to add a new contact or create a group, plus a list of
/// existing Reacti contacts to chat with.
class NewChatScreen extends StatefulWidget {
  /// Creates the new-chat screen.
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

/// State for [NewChatScreen]; holds the contact list and builds the layout.
class _NewChatScreenState extends State<NewChatScreen> {
  /// Placeholder contact list shown under "Contacts On Reacti".
  ///
  /// Currently hard-coded sample data pending integration with a real
  /// contacts data source.
  final List<NewchatModel> newchats = [
    NewchatModel(
      name: 'Mk Azizi ',
      username: '@Mutual',
      imageUrl:
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
    ),
    NewchatModel(
      name: 'Farzina Akter',
      username: '@Mutual',
      imageUrl:
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
    ),
  ];
  /// Builds the scaffold: a search app bar, "New Contact"/"New Group"
  /// shortcuts, and the list of existing contacts.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Container(
          height: 40.h,
          padding: EdgeInsets.only(left: 12.w),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.allPrimaryColor, width: 1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by any Groupe Or Name ',
              hintStyle: TextFontStyle.headline14w400C666666Poppins.copyWith(
                color: AppColors.allPrimaryColor,
              ),
              suffixIcon: Icon(Icons.search, color: AppColors.allPrimaryColor),
              border: InputBorder.none,
            ),
            style: TextStyle(color: AppColors.allPrimaryColor),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                log("New Contact");
                // Handle tap event
              },
              child: Row(
                children: [
                  SvgPicture.asset(Assets.icons.newContact, height: 42.h),
                  UIHelper.horizontalSpace(12.w),
                  Text(
                    'New Contact',
                    style: TextFontStyle.headline18w400CFFFFFFPoppins.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            UIHelper.verticalSpace(16.h),
            GestureDetector(
              onTap: () {
                log("New Group");
                NavigationService.navigateTo(Routes.createGroupRoute);
                // Handle tap event
              },
              child: Row(
                children: [
                  SvgPicture.asset(Assets.icons.newGroup, height: 42.h),
                  UIHelper.horizontalSpace(12.w),
                  Text(
                    'New Group',
                    style: TextFontStyle.headline18w400CFFFFFFPoppins.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            UIHelper.verticalSpace(16.h),
            Text(
              "Contacts On Reacti",
              style: TextFontStyle.headline16w400CCCCCCCPoppins,
              textAlign: TextAlign.start,
            ),
            UIHelper.verticalSpace(16.h),
            newchats.isEmpty
                ? Center(
                  child: Text(
                    'No contacts yet',
                    style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                      color: AppColors.cE5E5E5,
                    ),
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: newchats.length,
                  itemBuilder: (context, index) {
                    final newchat = newchats[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      color: AppColors.c161618,
                      margin: EdgeInsets.only(bottom: 12.h),
                      child: ListTile(
                        leading: ClipOval(
                          child: CustomNetworkImage(
                            height: 50.h,
                            width: 50.w,
                            urls: newchat.imageUrl,
                          ),
                        ),
                        title: Text(
                          newchat.name,
                          style: TextFontStyle.headline18w400CFFFFFFPoppins
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          newchat.username,
                          style: TextFontStyle.headline14w400C666666Poppins
                              .copyWith(color: AppColors.cCCCCCC),
                        ),

                        onTap: () {
                          log("Open Chat with ${newchat.name}");
                          // Handle newchat tap
                        },
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
