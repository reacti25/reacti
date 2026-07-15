import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/search/model/all_user_response.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/networks/api_access.dart';
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

  /// User-ids whose friend request is mid-flight, used to disable the
  /// Send Request button between the tap and the follow-up search refetch so
  /// a quick double-tap can't fire the request twice.
  final Set<int> _sendingRequestIds = {};

  /// Runs a username-only search. Discovery is deliberately by-username: an
  /// empty query returns no one, so the screen never shows the whole directory.
  Future<bool> _runSearch(String query) =>
      searchUserRx.searchUser(search: query, mode: 'username');

  /// Opens with an empty result set (no full-directory browse) so the user is
  /// prompted to search by username.
  @override
  void initState() {
    _runSearch("");
    super.initState();
  }

  /// Disposes the search controller and resets the result stream on exit.
  @override
  void dispose() {
    _searchController.dispose();
    _searchController.clear();
    // Reset results so a future visit to this screen starts clean.
    _runSearch("");
    super.dispose();
  }

  /// Toggles the app bar between title and search-input modes.
  ///
  /// When closing search, the field is cleared and results reset to empty.
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _runSearch("").waitingForSuccess();
      }
    });
  }

  /// Re-runs the search whenever the query [value] changes.
  void _onSearchChanged(String value) {
    _runSearch(value);
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
                  style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search by username",
                    hintStyle: TextFontStyle.headline16w400CFFFFFFPoppins
                        .copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14.sp,
                        ),
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearchChanged,
                )
                : Text(
                  "Search",
                  style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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
              // Empty query → prompt to search; non-empty → genuine no-match.
              final promptToSearch = _searchController.text.trim().isEmpty;
              return Center(
                child: Text(
                  promptToSearch
                      ? "Search for a friend by their username"
                      : "No users found",
                ),
              );
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
                              style: TextFontStyle.headline16w500CFFFFFFPoppins
                                  .copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            UIHelper.verticalSpace(4.h),
                            Text(
                              data?.username ?? "",
                              style: TextFontStyle.headline16w400CFFFFFFPoppins
                                  .copyWith(
                                    fontSize: 12.sp,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            // if (data?.isFriend != true)
                            UIHelper.verticalSpace(8.h),
                            if (data?.isFriend != true &&
                                data?.isRequestSent != true)
                              CustomButton(
                                // Disable (greys out) while the request is in
                                // flight so a double-tap can't send twice.
                                onTap:
                                    _sendingRequestIds.contains(data?.id)
                                        ? null
                                        : () {
                                          setState(
                                            () => _sendingRequestIds.add(
                                              data!.id!,
                                            ),
                                          );
                                          sendRequestRx
                                              .sendRequest(id: data!.id!)
                                              .waitingForSuccess()
                                              .then((success) {
                                                if (!mounted) return;
                                                setState(
                                                  () => _sendingRequestIds
                                                      .remove(data.id!),
                                                );
                                                if (success) {
                                                  ToastUtil.showSuccessMessage(
                                                    "Friend request sent",
                                                  );
                                                  // Re-run the search so this
                                                  // row flips to "Requested"
                                                  // immediately (its state comes
                                                  // from the search response,
                                                  // not the request list).
                                                  _runSearch(
                                                    _searchController.text,
                                                  );
                                                }
                                              });
                                        },
                                btnName:
                                    _sendingRequestIds.contains(data?.id)
                                        ? "Sending…"
                                        : "Send Request",
                                height: 30.h,
                              ),

                            if (data?.isFriend == true)
                              CustomButton(
                                onTap: () {
                                  getInboxMessageRx
                                      .getInboxMessage(id: data!.id!)
                                      .waitingForSuccess()
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
                                      .waitingForSuccess()
                                      .then((success) {
                                        if (success) {
                                          // Re-run the search so this row's
                                          // button flips back to "Send Request"
                                          // immediately.
                                          _runSearch(_searchController.text);
                                        }
                                      });
                                },
                                // Reads as an already-sent status; the ✕ is the
                                // affordance to cancel the pending request.
                                btnName: "Requested  ✕",
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
