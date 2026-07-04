import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../gen/assets.gen.dart';
import '../../../helpers/loading_helper.dart';
import '../../../networks/api_access.dart';
import '../../friends/model/get_request_response.dart';
import '../../friends/presentation/requests_widget.dart';

/// Screen presenting incoming and outgoing friend requests in two tabs.
///
/// The "Friend requests" tab delegates to [RequestsScreen]; the "Sent
/// requests" tab streams outgoing requests and allows cancelling them.
class RequestScreen extends StatefulWidget {
  /// Creates the requests screen.
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

/// State for [RequestScreen]; preloads both request lists and builds the tabs.
class _RequestScreenState extends State<RequestScreen> {
  /// Loads both the sent and received request lists when the screen opens.
  @override
  void initState() {
    getSentRequestRx.getSentRequestList();
    getRequestRx.getRequest();
    super.initState();
  }

  /// Builds the scaffold: a [DefaultTabController] with "Friend requests" and
  /// "Sent requests" tabs.
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Requests",
            style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              TabBar(
                labelStyle: TextFontStyle.headline16w500C333333Poppins.copyWith(
                  fontSize: 14.sp,
                ),
                unselectedLabelStyle: TextFontStyle.headline16w500C333333Poppins
                    .copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14.sp,
                    ),
                indicator: BoxDecoration(
                  color: AppColors.allPrimaryColor,
                  borderRadius: BorderRadius.circular(36.r),
                ),
                tabs: [
                  Tab(text: "Friend requests"),
                  Tab(text: "Sent requests"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: RequestsScreen(),
                    ),
                    StreamBuilder(
                      stream: getSentRequestRx.getSentRequestStream,
                      builder: (context, asyncSnapshot) {
                        if (asyncSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (asyncSnapshot.hasData) {
                          GetRequestResponse response = asyncSnapshot.data;
                          return response.data!.requests!.isEmpty
                              ? Center(
                                child: Text(
                                  "You haven't sent any request",
                                  style: TextFontStyle
                                      .headline14w500CFFFFFFPoppins
                                      .copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                ),
                              )
                              : ListView.builder(
                                padding: EdgeInsets.only(top: 16.h),
                                shrinkWrap: true,
                                physics: BouncingScrollPhysics(),
                                itemCount: response.data?.requests?.length,
                                itemBuilder: (context, index) {
                                  final friend =
                                      response.data?.requests?[index];
                                  return Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    margin: EdgeInsets.only(bottom: 12.h),
                                    child: ListTile(
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              cancelRequestRx
                                                  .cancelRequest(
                                                    id: friend!.person!.id!,
                                                  )
                                                  .waitingForSuccess()
                                                  .then((success) {
                                                    if (success) {
                                                      getSentRequestRx
                                                          .getSentRequestList();
                                                    }
                                                  });
                                              // log("Reject tapped for ${friend.name}");
                                              // Implement reject functionality
                                            },
                                            child: SvgPicture.asset(
                                              Assets.icons.close,
                                            ),
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
                                        style: TextFontStyle
                                            .headline18w400CFFFFFFPoppins
                                            .copyWith(
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                            ),
                                      ),
                                      subtitle: Text(
                                        friend?.person?.username ?? "",
                                        style: TextFontStyle
                                            .headline14w400C666666Poppins
                                            .copyWith(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
