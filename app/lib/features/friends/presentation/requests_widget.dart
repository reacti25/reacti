import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../model/get_request_response.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: getRequestRx.getRequestStream,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (asyncSnapshot.hasData) {
          GetRequestResponse response = asyncSnapshot.data;

          return Scaffold(
            body:
                response.data!.requests!.isEmpty
                    ? Center(
                      child: Text(
                        'No friend request yet.',
                        style: TextFontStyle.headline14w400C666666Poppins
                            .copyWith(color: AppColors.cE5E5E5),
                      ),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: BouncingScrollPhysics(),
                      itemCount: response.data?.requests?.length,
                      itemBuilder: (context, index) {
                        final friend = response.data?.requests?[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          color: AppColors.c161618,
                          margin: EdgeInsets.only(bottom: 12.h),
                          child: ListTile(
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    acceptRequestRx
                                        .acceptRequest(id: friend!.person!.id!)
                                        .waitingForSucess()
                                        .then((success) {
                                          if (success) {
                                            ToastUtil.showSuccessMessage(
                                              "Request accepted",
                                            );
                                            getRequestRx.getRequest();
                                            getFriendListRx.getFriendList();
                                            // getRequestRx.getRequest();
                                          }
                                        });
                                    // log(
                                    //   // "Accept tapped for ${friend?.fullName}",
                                    // );
                                    // Implement accept functionality
                                  },
                                  child: SvgPicture.asset(Assets.icons.check),
                                ),
                                UIHelper.horizontalSpace(12.w),
                                GestureDetector(
                                  onTap: () {
                                    declineRequestRx
                                        .declineRequest(id: friend!.person!.id!)
                                        .waitingForSucess()
                                        .then((success) {
                                          if (success) {
                                            getRequestRx.getRequest();
                                          }
                                        });
                                    // log("Reject tapped for ${friend.name}");
                                    // Implement reject functionality
                                  },
                                  child: SvgPicture.asset(Assets.icons.close),
                                ),
                              ],
                            ),
                            leading: ClipOval(
                              child: CustomNetworkImage(
                                height: 50.h,
                                width: 50.w,
                                urls: friend?.person?.avatar ?? "",
                              ),
                            ),
                            title: Text(
                              friend?.person?.firstName ?? "",
                              style: TextFontStyle.headline18w400CFFFFFFPoppins
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              friend?.person?.username ?? "",
                              style: TextFontStyle.headline14w400C666666Poppins
                                  .copyWith(color: AppColors.cCCCCCC),
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
