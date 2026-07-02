import 'dart:developer';

import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/group_details/model/group_details_response.dart';
import 'package:reacti_app/features/group_details/model/group_media_response.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../constants/text_font_style.dart';
import '../../../helpers/loading_helper.dart';

/// Screen showing a group's profile with two tabs: members and shared media.
///
/// Renders the group avatar, name and member count in the app bar, an
/// overflow menu whose entries depend on the viewer's role, a scrollable
/// member list, and a grid of shared media.
class GroupDetailsScreen extends StatefulWidget {
  /// Identifier of the group whose details are displayed.
  final int id;

  /// Creates a [GroupDetailsScreen] for the group [id].
  const GroupDetailsScreen({super.key, required this.id});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

/// State for [GroupDetailsScreen]; triggers the media fetch on first build.
class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  @override
  void initState() {
    apiCall();
    super.initState();
  }

  /// Fetches the group's media list so the media tab has data to show.
  Future<void> apiCall() async {
    await getGroupMediaRx.groupMediaList(id: widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: StreamBuilder(
        stream: groupDetailsRx.getGroupDetailsStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (asyncSnapshot.hasData) {
            GroupDetailsResponse response = asyncSnapshot.data;
            final group = response.data?.group;
            return Scaffold(
              appBar: AppBar(
                centerTitle: false,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3.h,
                  children: [
                    Text(
                      group?.name ?? "",
                      style: TextFontStyle.headline16w500CFFFFFFPoppins,
                    ),
                    Text(
                      '${group?.memberCount ?? 0} Members',
                      style: TextFontStyle.headline12w400CFFFFFFPoppins,
                    ),
                  ],
                ),
                actions: [
                  Builder(
                    builder: (context) {
                      final myUserId = appData.read(kKeyUserId);

                      // Resolve the viewer's role from the member list so the
                      // overflow menu can be tailored to their permissions;
                      // fall back to 'member' when they are not found.
                      final myRole =
                          group?.members
                              ?.firstWhere(
                                (m) => m.user?.id == myUserId,
                                orElse: () => Member(role: 'member'),
                              )
                              .role ??
                          'member';

                      return PopupMenuButton<String>(
                        onSelected: (String value) {
                          switch (value) {
                            case 'edit':
                              log('Edit group');
                              NavigationService.navigateToWithArgs(
                                Routes.editGroupRoute,
                                {'groupId': widget.id},
                              );
                              break;
                            case 'add_member':
                              log('Add Member');
                              NavigationService.navigateToWithArgs(
                                Routes.addMemberRoute,
                                {'groupId': widget.id},
                              );
                              break;
                            case 'leave':
                              log('Leave group');
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          final List<PopupMenuEntry<String>> menuItems = [];

                          // Owner/Admin: Edit & Add Member
                          if (myRole == 'owner' || myRole == 'admin') {
                            menuItems.addAll([
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit Group'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'add_member',
                                child: Text('Add Member'),
                              ),
                            ]);
                          }

                          // 🚫 Owner should NOT see Leave Group
                          if (myRole != 'owner') {
                            menuItems.addAll([
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'leave',
                                child: Text(
                                  'Leave Group',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ]);
                          }

                          return menuItems;
                        },

                        icon: Icon(
                          Icons.more_vert,
                          color: context.reacti.iconPrimary,
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    UIHelper.verticalSpace(14.h),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.allPrimaryColor,
                                width: 2.sp,
                              ),
                            ),
                            child: ClipOval(
                              child: CustomNetworkImage(
                                height: 90.h,
                                width: 90.w,
                                urls: group?.avatar ?? "",
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(6.sp),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.allPrimaryColor,
                              ),
                              child: SvgPicture.asset(
                                Assets.icons.cameraIcon,
                                height: 16.h,
                                width: 16.w,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    UIHelper.verticalSpace(20.h),

                    TabBar(
                      indicator: UnderlineTabIndicator(
                        borderSide: BorderSide(
                          width: 2.4.w,
                          color: AppColors.allPrimaryColor,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(5.r),
                        ),
                      ),
                      labelStyle: TextFontStyle.headline16w500CFFFFFFPoppins,
                      tabs: [
                        Tab(text: "Members (${group?.memberCount ?? 0})"),
                        Tab(text: "Media"),
                      ],
                    ),

                    Container(
                      color: AppColors.allPrimaryColor.withValues(alpha: 0.3),
                      height: 1.h,
                      width: double.infinity,
                    ),

                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView.builder(
                            itemCount: group?.members?.length ?? 0,
                            padding: EdgeInsets.only(top: 16.h),
                            physics: BouncingScrollPhysics(),
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final data = group?.members?[index];
                              return GroupMemberListTile(
                                id: widget.id,
                                data: data,
                                members: group?.members,
                              );
                            },
                          ),
                          StreamBuilder(
                            stream: getGroupMediaRx.getGroupMediaStream,
                            builder: (context, asyncSnapshot2) {
                              if (asyncSnapshot2.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              } else if (asyncSnapshot2.hasData) {
                                GroupMediaResponse response =
                                    asyncSnapshot2.data;
                                return GroupImageGrid(response: response);
                              } else {
                                return SizedBox.shrink();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return SizedBox.shrink();
          }
        },
      ),
    );
  }
}

/// Three-column grid that displays every media item in a group.
///
/// Used as the content of the group-details "Media" tab.
class GroupImageGrid extends StatelessWidget {
  /// Creates a [GroupImageGrid] from a resolved [response].
  const GroupImageGrid({super.key, required this.response});

  /// The media response whose items are laid out in the grid.
  final GroupMediaResponse response;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4.h,
        crossAxisSpacing: 4.w,
      ),
      itemCount: response.data?.media?.length,
      itemBuilder: (context, index) {
        final groupImage = response.data?.media?[index];
        return Container(
          // height: 100.h,
          // width: 100.w,
          decoration: BoxDecoration(color: AppColors.c161618),
          child: CustomNetworkImage(
            borderRadius: 4.r,
            urls: groupImage?.fileUrl ?? "",
            // fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

/// List tile for one group member, with a role badge and a moderation menu.
///
/// The overflow menu (make admin, remove admin, remove from group) is only
/// shown when the viewer's role grants permission over the target member.
class GroupMemberListTile extends StatelessWidget {
  /// Creates a [GroupMemberListTile] for member [data] within group [id].
  const GroupMemberListTile({
    super.key,
    required this.data,
    required this.members,
    required this.id,
  });

  /// Identifier of the group this member belongs to.
  final int id;

  /// The member rendered by this tile.
  final Member? data;

  /// The full member list, used to resolve the viewer's own role.
  final List<Member>? members;

  @override
  Widget build(BuildContext context) {
    final myUserId = appData.read(kKeyUserId);

    // Resolve the viewer's role from the member list to decide which
    // moderation actions are permitted; default to 'member' if absent.
    final myRole =
        members
            ?.firstWhere(
              (m) => m.user?.id == myUserId,
              orElse: () => Member(role: 'member'),
            )
            .role ??
        'member';

    final memberRole = data?.role ?? 'member';
    final isMyself = myUserId == data?.user?.id;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(10.sp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.c161618,
      ),
      child: Row(
        spacing: 12.w,
        children: [
          ClipOval(
            child: CustomNetworkImage(
              width: 40.w,
              height: 40.h,
              urls: data?.user?.avatar ?? "",
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4.h,
              children: [
                Row(
                  spacing: 12.w,
                  children: [
                    Text(
                      "${data?.user?.firstName} ${data?.user?.lastName}",
                      style: TextFontStyle.headline16w500CFFFFFFPoppins,
                    ),
                    memberRole == 'member'
                        ? SizedBox.shrink()
                        : Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.allPrimaryColor,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            memberRole,
                            style: TextFontStyle.headline12w400CFFFFFFPoppins
                                .copyWith(color: AppColors.c000000),
                          ),
                        ),
                  ],
                ),
                Text(
                  data?.user?.lastActivityAt ?? "",
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    color: AppColors.cFFFFFF.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // 🚫 Hide menu if:
          // 1️⃣ It's me (isMyself)
          // 2️⃣ OR myRole == 'member' (no permission)
          if (!isMyself &&
              myRole != 'member' &&
              !(myRole == 'admin' && memberRole == 'owner'))
            SizedBox(
              height: 25.h,
              width: 25.w,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.reacti.iconPrimary),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'make_admin':
                      log(
                        "Make Admin pressed for ${data?.user?.firstName} ${data?.user?.lastName} user id ${data!.user!.id!} Group ID $id",
                      );

                      // Promote the member, then refresh group details so the
                      // updated role badge is reflected in the list.
                      makeGroupAdminRx
                          .makeGroupAdmin(groupId: id, userId: data!.user!.id!)
                          .waitingForSuccess()
                          .then((success) {
                            if (success) {
                              groupDetailsRx.getGroupDetails(id: id);
                            }
                          });
                      // Api Call for make group admin
                      break;
                    case 'remove_admin':
                      log("Remove Admin pressed for ${data?.user?.firstName}");
                      break;
                    case 'remove':
                      // Remove the member, then refresh group details so the
                      // member disappears from the list on success.
                      removeMemberRx
                          .removeMember(groupId: id, userId: data!.user!.id!)
                          .waitingForSuccess()
                          .then((success) {
                            if (success) {
                              groupDetailsRx.getGroupDetails(id: id);
                            }
                          });
                      log("Remove Member pressed for ${data?.user?.firstName}");
                      break;
                  }
                },
                itemBuilder: (context) {
                  final List<PopupMenuEntry<String>> menuItems = [];

                  // 👑 Owner permissions
                  if (myRole == 'owner') {
                    if (memberRole == 'admin') {
                      menuItems.addAll([
                        PopupMenuItem(
                          value: 'remove_admin',
                          child: Text("Remove Admin", style: _menuStyle),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text("Remove from Group", style: _menuStyle),
                        ),
                      ]);
                    } else if (memberRole == 'member') {
                      menuItems.addAll([
                        PopupMenuItem(
                          value: 'make_admin',
                          child: Text("Make Admin", style: _menuStyle),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text("Remove from Group", style: _menuStyle),
                        ),
                      ]);
                    }
                  }
                  // 🧩 Admin permissions
                  else if (myRole == 'admin') {
                    if (memberRole == 'member') {
                      menuItems.add(
                        PopupMenuItem(
                          value: 'remove',
                          child: Text("Remove from Group", style: _menuStyle),
                        ),
                      );
                    }
                  }

                  return menuItems;
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Shared text style for the moderation popup menu entries.
  TextStyle get _menuStyle => TextFontStyle.headline12w400CFFFFFFPoppins
      .copyWith(color: AppColors.c000000);
}
