import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../constants/text_font_style.dart';
import '../../../gen/assets.gen.dart';
import '../../../gen/colors.gen.dart';
import '../../../networks/api_access.dart';
import '../../friends/model/get_request_response.dart';

class SentRequestScreen extends StatefulWidget {
  const SentRequestScreen({super.key});

  @override
  State<SentRequestScreen> createState() => _SentRequestScreenState();
}

class _SentRequestScreenState extends State<SentRequestScreen> {
  @override
  void initState() {
    getSentRequestRx.getSentRequestList();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          "Sent Requests",
          style: TextFontStyle.headline20w600CFFFFFFPoppins,
        ),
      ),
      body: StreamBuilder(
        stream: getSentRequestRx.getSentRequestStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (asyncSnapshot.hasData) {
            GetRequestResponse response = asyncSnapshot.data;
            return response.data!.requests!.isEmpty
                ? Center(
                  child: Text(
                    "You haven't sent any request",
                    style: TextFontStyle.headline14w500CFFFFFFPoppins,
                  ),
                )
                : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                                cancelRequestRx
                                    .cancelRequest(id: friend!.person!.id!)
                                    .waitingForSucess()
                                    .then((success) {
                                      if (success) {
                                        getSentRequestRx.getSentRequestList();
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
                );
          } else {
            return SizedBox.shrink();
          }
        },
      ),
    );
  }
}
