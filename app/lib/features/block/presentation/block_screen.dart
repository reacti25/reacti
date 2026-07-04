import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../model/block_list_response.dart';

/// Screen that lists the users the signed-in user has blocked.
///
/// Renders each blocked user as a card with an avatar, name and block date,
/// plus an "Unblock" button. An empty list shows a placeholder message.
class BlockScreen extends StatefulWidget {
  /// Creates the block-users screen.
  const BlockScreen({super.key});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

/// State for [BlockScreen]; loads the blocked-user list on first build.
class _BlockScreenState extends State<BlockScreen> {
  /// Triggers an initial fetch of the blocked-user list when the screen
  /// mounts so the stream has data to render.
  @override
  void initState() {
    getBlockUserListRx.getBlockUserList();
    super.initState();
  }

  /// Builds the blocked-user list.
  ///
  /// The body subscribes to `getBlockUserListRx.getBlockListStream`: it shows
  /// a spinner while loading, the list (or an empty-state message) once data
  /// arrives, and an empty box otherwise. Tapping "Unblock" toggles the block
  /// via `blockUserRx` and refetches the list on success.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Blocked Users',
          style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
            color: context.reacti.textPrimary,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: getBlockUserListRx.getBlockListStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (asyncSnapshot.hasData) {
            BlockListResponse response = asyncSnapshot.data;
            return response.data!.blockedUsers!.isEmpty
                ? Center(
                  child: Text(
                    "No blocked users found",
                    style: TextFontStyle.headline14w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textSecondary,
                    ),
                  ),
                )
                : ListView.builder(
                  padding: EdgeInsets.only(top: 6.h),
                  itemCount: response.data?.blockedUsers?.length ?? 0,
                  itemBuilder: (context, index) {
                    final data = response.data?.blockedUsers?[index];
                    return Container(
                      padding: EdgeInsets.all(12.sp),
                      margin: EdgeInsets.only(
                        bottom: 16.h,
                        left: 16.w,
                        right: 16.w,
                      ),
                      decoration: BoxDecoration(
                        color: context.reacti.card,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: context.reacti.cardShadow,
                      ),
                      child: Row(
                        spacing: 12.w,
                        children: [
                          ClipOval(
                            child: CustomNetworkImage(
                              height: 50.h,
                              width: 50.w,
                              urls: data?.blockedUser?.avatar ?? "",
                            ),
                          ),
                          Expanded(
                            child: Column(
                              spacing: 6.h,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data?.blockedUser?.firstName ?? "",
                                  style: TextFontStyle
                                      .headline16w500CF7F7F7Poppins
                                      .copyWith(
                                        color: context.reacti.textPrimary,
                                      ),
                                ),
                                Text(
                                  "Blocked at ${data?.createdAt ?? ""}",
                                  style: TextFontStyle
                                      .headline12w400CFFFFFFPoppins
                                      .copyWith(
                                        color: context.reacti.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.reacti.brandFill,
                              foregroundColor: context.reacti.onBrandFill,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () {
                              blockUserRx
                                  .blockUser(id: data?.blockedUser?.id ?? 0)
                                  .waitingForSuccess()
                                  .then((success) async {
                                    if (success) {
                                      await getBlockUserListRx
                                          .getBlockUserList();
                                      // NavigationService.goBack;
                                    }
                                  });
                            },
                            child: Text("Unblock"),
                          ),
                        ],
                      ),
                    );
                  },
                );
          } else {
            return SizedBox.shrink();
          }
        },
      ),
    );
  }
}
