import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/search/model/all_user_response.dart';
import 'package:achiar_expert_app/helpers/all_routes.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Screen for finding other users and acting on the result.
///
/// Shows a toggleable search field in the app bar and a streamed list of
/// matching users, each with a contextual action (send request, message or
/// cancel a pending request).
class SearchScreen extends StatefulWidget {
  /// Creates the user-search screen.
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// State for [SearchScreen]; manages the search field and result stream.
class _SearchScreenState extends State<SearchScreen> {
  /// Whether the app bar currently shows the search input instead of a title.
  bool _isSearching = false;

  /// Controller backing the search text field.
  final TextEditingController _searchController = TextEditingController();

  /// Loads the default (empty-query) user list when the screen opens.
  @override
  void initState() {
    searchUserRx.searchUser(search: "");
    super.initState();
  }

  /// Disposes the search controller and resets the result stream on exit.
  @override
  void dispose() {
    _searchController.dispose();
    _searchController.clear();
    // Reset results so a future visit to this screen starts clean.
    searchUserRx.searchUser(search: "");
    super.dispose();
  }

  /// Toggles the app bar between title and search-input modes.
  ///
  /// When closing search, the field is cleared and the default list reloaded.
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        searchUserRx.searchUser(search: "").waitingForSucess();
      }
    });
  }

  /// Re-runs the search whenever the query [value] changes.
  void _onSearchChanged(String value) {
    searchUserRx.searchUser(search: value);
  }

  /// Builds the scaffold: a toggleable search app bar and a [StreamBuilder]
  /// rendering the matching users with their contextual actions.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? TextFormField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  decoration: InputDecoration(
                    hintText: "Search user...",
                    hintStyle: TextFontStyle.headline16w400CFFFFFFPoppins
                        .copyWith(color: Colors.white70, fontSize: 14.sp),
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearchChanged,
                )
                : Text(
                  "Search",
                  style: TextFontStyle.headline20w600CFFFFFFPoppins,
                ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          // UIHelper.horizontalSpace(16.w),
        ],
      ),
      body: StreamBuilder(
        stream: searchUserRx.getSearchStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (asyncSnapshot.hasData) {
            final AllUserResponse response = asyncSnapshot.data;

            if (response.data?.data?.isEmpty ?? true) {
              return const Center(child: Text("No users found"));
            }

            return ListView.builder(
              itemCount: response.data?.data?.length,
              itemBuilder: (context, index) {
                final data = response.data?.data?[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 8.h, left: 16.w, right: 16.w),
                  padding: EdgeInsets.all(10.sp),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipOval(
                        child: CustomNetworkImage(
                          urls: data?.avatar ?? "",
                          height: 70.h,
                          width: 70.w,
                        ),
                      ),
                      UIHelper.horizontalSpace(12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data?.fullName ?? "",
                              style: TextFontStyle.headline16w500CFFFFFFPoppins,
                            ),
                            UIHelper.verticalSpace(4.h),
                            Text(
                              data?.username ?? "",
                              style: TextFontStyle.headline16w400CFFFFFFPoppins
                                  .copyWith(fontSize: 12.sp),
                            ),
                            // if (data?.isFriend != true)
                            UIHelper.verticalSpace(8.h),
                            if (data?.isFriend != true &&
                                data?.isRequestSent != true)
                              CustomButton(
                                onTap: () {
                                  sendRequestRx
                                      .sendRequest(id: data!.id!)
                                      .waitingForSucess()
                                      .then((success) {
                                        if (success) {
                                          ToastUtil.showSuccessMessage(
                                            "Friend request sent",
                                          );
                                          getRequestRx.getRequest();
                                        }
                                      });
                                },
                                btnName: "Send Request",
                                height: 30.h,
                              ),

                            if (data?.isFriend == true)
                              CustomButton(
                                onTap: () {
                                  getInboxMessageRx
                                      .getInboxMessage(id: data!.id!)
                                      .waitingForSucess()
                                      .then((success) {
                                        NavigationService.navigateToWithArgs(
                                          Routes.inboxRoute,
                                          {
                                            'id': data.id,
                                            'roomId': getInboxMessageRx.roomId,
                                            'name': data.fullName ?? "",
                                            'image': data.avatar ?? "",
                                          },
                                        );
                                      });
                                },
                                btnName: "Message",
                                height: 30.h,
                              ),

                            if (data?.isRequestSent == true)
                              CustomButton(
                                onTap: () {
                                  cancelRequestRx
                                      .cancelRequest(id: data!.id!)
                                      .waitingForSucess()
                                      .then((success) {
                                        if (success) {
                                          getSentRequestRx.getSentRequestList();
                                        }
                                      });
                                },
                                btnName: "Cancel",
                                height: 30.h,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
