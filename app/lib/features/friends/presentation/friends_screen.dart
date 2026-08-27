import 'dart:developer';

import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/common_widget/load_error_retry.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:flutter/material.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
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
  const FriendsScreen({super.key, this.query = '', this.onFindFromContacts});

  /// Switches to the Contacts tab, which lives in the parent.
  final VoidCallback? onFindFromContacts;

  /// Live text from the search bar above this tab, or empty for no filter.
  ///
  /// Deliberately as permissive as the Contacts filter and nothing like the
  /// user search: these are people you have already accepted, so one letter
  /// surfacing all of them is the point, not a leak.
  final String query;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

/// State for [FriendsScreen]; rebuilds reactively from the friend-list stream.
class _FriendsScreenState extends State<FriendsScreen> {
  /// The empty state for an account with no friends yet.
  ///
  /// Two ways forward rather than a bare line of text. This is where the
  /// walkthrough's "Start here" mark sends a brand-new user, and it used to say
  /// "No friends yet" and nothing else — the one screen in the app whose whole
  /// job is to be someone's next step, with no next step on it.
  Widget _buildNoFriendsYet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56.r, color: scheme.outline),
            SizedBox(height: 16.h),
            Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Add someone to send your first Reacti.',
              textAlign: TextAlign.center,
              style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 20.h),
            // Contacts first: people you already know are the likeliest first
            // Reacti, and matching them needs no username anyone has to
            // remember.
            FilledButton.icon(
              onPressed: widget.onFindFromContacts,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Find friends from contacts'),
            ),
            SizedBox(height: 4.h),
            TextButton(
              onPressed: () => NavigationService.navigateTo(Routes.searchRoute),
              child: const Text('Search by username'),
            ),
          ],
        ),
      ),
    );
  }

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
          final all = response.data ?? [];
          final q = widget.query.trim().toLowerCase();
          final friends =
              q.isEmpty
                  ? all
                  : all
                      .where((f) => (f.name ?? '').toLowerCase().contains(q))
                      .toList();

          if (all.isNotEmpty && friends.isEmpty) {
            return Scaffold(
              body: Center(
                child: Text(
                  'No friends match "${widget.query.trim()}"',
                  textAlign: TextAlign.center,
                  style: TextFontStyle.headline14w400C666666Poppins.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            body:
                friends.isEmpty
                    ? _buildNoFriendsYet(context)
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: BouncingScrollPhysics(),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final row = Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          color: Theme.of(context).colorScheme.surface,
                          margin: EdgeInsets.only(bottom: 12.h),
                          child: ListTile(
                            leading: ClipOval(
                              child: CustomNetworkImage(
                                height: 50.h,
                                width: 50.w,
                                urls: friend.avatar ?? "",
                              ),
                            ),
                            title: Text(
                              friend.name ?? "",
                              style: TextFontStyle.headline18w400CFFFFFFPoppins
                                  .copyWith(
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            subtitle: Text(
                              friend.username ?? "",
                              style: TextFontStyle.headline14w400C666666Poppins
                                  .copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            onTap: () {
                              // Load the chat history first so the room id is
                              // known before navigating into the inbox.
                              getInboxMessageRx
                                  .getInboxMessage(id: friend.id!)
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
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  size: 24.r,
                                ),
                                // Menu background from popupMenuTheme (themed).
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                elevation: 4,
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'unfriend') {
                                    log("Unfriend User: ${friend.name}");
                                    unfriendUserRx
                                        .unfriendUser(id: friend.id!)
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

                        // Only the top row, and only while the user has not
                        // been shown how to start a chat yet. A brand-new
                        // account reaches its first conversation from HERE, not
                        // from the Chat tab — a 1:1 appears in the chat list
                        // only once messages exist, so for them that tab is
                        // still empty and its mark never fires.
                        //
                        // Not while searching: the top row is then whatever
                        // they typed, and spending the tip on it teaches
                        // nothing.
                        if (index != 0 || q.isNotEmpty) return row;
                        return TourMark(
                          markKey: FirstRunTour.friendRowKey,
                          showOnceKey: kKeyTourFirstChatSeen,
                          title: 'Open a chat',
                          description:
                              'Tap them to start a chat and send your first '
                              'Reacti.',
                          child: row,
                        );
                      },
                    ),
          );
        } else if (asyncSnapshot.hasError) {
          // A failed load previously showed a blank screen; surface a message
          // and a retry that re-fetches the friend list.
          return LoadErrorRetry(
            message: "Couldn't load your friends.",
            onRetry: () => getFriendListRx.getFriendList(),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }
}
