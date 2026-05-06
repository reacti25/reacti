import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../model/block_list_response.dart';

class BlockScreen extends StatefulWidget {
  const BlockScreen({super.key});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  @override
  void initState() {
    getBlockUserListRx.getBlockUserList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Block Users',
          style: TextFontStyle.headline16w500CFFFFFFPoppins,
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
                    style: TextFontStyle.headline14w500CFFFFFFPoppins,
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
                        color: AppColors.c161618,
                        borderRadius: BorderRadius.circular(12.r),
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
                                  style:
                                      TextFontStyle
                                          .headline16w500CF7F7F7Poppins,
                                ),
                                Text(
                                  "Blocked at ${data?.createdAt ?? ""}",
                                  style:
                                      TextFontStyle
                                          .headline12w400CFFFFFFPoppins,
                                ),
                              ],
                            ),
                          ),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.allPrimaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () {
                              blockUserRx
                                  .blockUser(id: data?.blockedUser?.id ?? 0)
                                  .waitingForSucess()
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
