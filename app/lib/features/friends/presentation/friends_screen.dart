import 'dart:developer';

import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../helpers/all_routes.dart';
import '../../../helpers/loading_helper.dart';
import '../../../helpers/navigation_service.dart';
import '../../../networks/api_access.dart';
import '../model/friend_list_response.dart';

/// A screen that displays the current user's confirmed friends.
///
/// Subscribes to [GetFriendListRx] and renders each friend with an avatar,
/// name, and an overflow menu for unfriending. Tapping a friend opens their
/// chat inbox.
class FriendsScreen extends StatefulWidget {
  /// Creates the friend-list screen.
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

/// State for [FriendsScreen]; rebuilds reactively from the friend-list stream.
class _FriendsScreenState extends State<FriendsScreen> {
  /// Builds the friend list from the latest [GetFriendListRx] stream value.
  ///
  /// Shows a spinner while waiting, an empty-state message when the user has
  /// no friends, and an interactive list otherwise.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: getFriendListRx.getFriendListStream,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (asyncSnapshot.hasData) {
          FriendListResponse response = asyncSnapshot.data;
          return Scaffold(
            body:
                response.data!.isEmpty
                    ? Center(
                      child: Text(
                        'No friends yet',
                        style: TextFontStyle.headline14w400C666666Poppins
                            .copyWith(color: AppColors.cE5E5E5),
                      ),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: BouncingScrollPhysics(),
                      itemCount: response.data?.length,
                      itemBuilder: (context, index) {
                        final friend = response.data?[index];
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
                                urls: friend?.avatar ?? "",
                              ),
                            ),
                            title: Text(
                              friend?.name ?? "",
                              style: TextFontStyle.headline18w400CFFFFFFPoppins
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              friend?.username ?? "",
                              style: TextFontStyle.headline14w400C666666Poppins
                                  .copyWith(color: AppColors.cCCCCCC),
                            ),
                            onTap: () {
                              // Load the chat history first so the room id is
                              // known before navigating into the inbox.
                              getInboxMessageRx
                                  .getInboxMessage(id: friend!.id!)
                                  .waitingForSuccess()
                                  .then((success) {
                                    NavigationService.navigateToWithArgs(
                                      Routes.inboxRoute,
                                      {
                                        'id': friend.id,
                                        'roomId': getInboxMessageRx.roomId,
                                        'name': friend.name ?? "",
                                        'image': friend.avatar ?? "",
                                      },
                                    );
                                  });
                            },
                            trailing: Container(
                              width: 20.w,
                              alignment: Alignment.center,

                              child: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 24.r,
                                ),
                                color: Colors.black, // Pure black
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                elevation: 4,
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'unfriend') {
                                    log("Unfriend User: ${friend?.name}");
                                    unfriendUserRx
                                        .unfriendUser(id: friend!.id!)
                                        .waitingForSuccess()
                                        .then((success) {
                                          // Refresh the list so the removed
                                          // friend disappears immediately.
                                          if (success) {
                                            getFriendListRx.getFriendList();
                                          }
                                        });
                                  }
                                },
                                itemBuilder:
                                    (BuildContext context) => [
                                      PopupMenuItem<String>(
                                        value: 'unfriend',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_remove,
                                              color: Colors.red,
                                              size: 20.r,
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Unfriend',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }
}
