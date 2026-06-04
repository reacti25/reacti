import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../model/get_request_response.dart';

/// A screen that lists the current user's incoming friend requests.
///
/// Subscribes to [GetRequestRx] and renders each pending request with the
/// requester's avatar and name, plus accept and decline actions.
class RequestsScreen extends StatefulWidget {
  /// Creates the friend-requests screen.
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

/// State for [RequestsScreen]; rebuilds reactively from the request stream.
class _RequestsScreenState extends State<RequestsScreen> {
  /// Builds the request list from the latest [GetRequestRx] stream value.
  ///
  /// Shows a spinner while waiting, an empty-state message when there are no
  /// requests, and an interactive list with accept/decline buttons otherwise.
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
                                        .waitingForSuccess()
                                        .then((success) {
                                          // Refresh both the request list and
                                          // the friend list so the accepted
                                          // user moves from one to the other.
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
                                        .waitingForSuccess()
                                        .then((success) {
                                          // Refresh the list so the declined
                                          // request is removed from view.
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
