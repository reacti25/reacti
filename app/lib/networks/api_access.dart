// Global registry of reactive data-source singletons.
//
// Each `*Rx` below is a single shared instance of an `RxResponseInt`
// subclass (see `networks/rx_base.dart`) — one per backend endpoint.
// Screens and widgets read these globals so they all observe the same
// stream, and tests can swap an instance for a fake (as the patent-flow
// widget tests do with `viewInboxImageRx` and `sendMessageRx`).

import 'package:reacti_app/features/auth/model/login_response.dart';
import 'package:reacti_app/features/chat/model/chat_list_response.dart';
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:reacti_app/features/create_group/data/rx_create_group/rx.dart';
import 'package:reacti_app/features/group_details/model/group_details_response.dart';
import 'package:reacti_app/features/privacy/model/privacy_response.dart';
import 'package:reacti_app/features/profile/data/rx_add_token/rx.dart';
import 'package:rxdart/rxdart.dart';

import '../features/auth/data/reset_pass/rx.dart';
import '../features/auth/data/rx_forget_pass/rx.dart';
import '../features/auth/data/rx_login/rx.dart';
import '../features/auth/data/rx_resend_forget_otp/rx.dart';
import '../features/auth/data/rx_signup/rx.dart';
import '../features/auth/data/rx_signup_verify/rx.dart';
import '../features/auth/data/verify_forget_otp/rx.dart';
import '../features/block/data/rx_block_user/rx.dart';
import '../features/block/data/rx_get_block_user_list/rx.dart';
import '../features/block/model/block_list_response.dart';
import '../features/change_password/data/rx_change_password/rx.dart';
import '../features/chat/data/rx_delete_message/rx.dart';
import '../features/chat/data/rx_get_all_chat/rx.dart';
import '../features/chat/data/rx_get_group_inbox/rx.dart';
import '../features/chat/data/rx_get_inbox_message/rx.dart';
import '../features/chat/data/rx_send_group_message/rx.dart';
import '../features/chat/data/rx_send_message/rx.dart';
import '../features/chat/data/rx_view_group_file/rx.dart';
import '../features/chat/data/rx_view_inbox_image/rx.dart';
import '../features/chat/model/group_inbox_response.dart';
import '../features/edit_group/data/rx_edit_group/rx.dart';
import '../features/edit_profile/data/rx_edit_profile/rx.dart';
import '../features/friends/data/rx_accept_request/rx.dart';
import '../features/friends/data/rx_cancel_request/rx.dart';
import '../features/friends/data/rx_decline_request/rx.dart';
import '../features/friends/data/rx_get_friend_list/rx.dart';
import '../features/friends/data/rx_get_request/rx.dart';
import '../features/friends/data/rx_get_sent_request/rx.dart';
import '../features/friends/data/rx_send_request/rx.dart';
import '../features/friends/data/rx_unfriend_user/rx.dart';
import '../features/friends/model/friend_list_response.dart';
import '../features/friends/model/get_request_response.dart';
import '../features/group_details/data/rx_group_details/rx.dart';
import '../features/group_details/data/rx_group_media/rx.dart';
import '../features/group_details/data/rx_make_admin/rx.dart';
import '../features/group_details/data/rx_remove_member/rx.dart';
import '../features/group_details/model/group_media_response.dart';
import '../features/privacy/data/rx_get_privacy/rx.dart';
import '../features/profile/data/rx_delete_account/rx.dart';
import '../features/profile/data/rx_get_profile/rx.dart';
import '../features/profile/data/rx_logout/rx.dart';
import '../features/profile/model/profile_response.dart';
import '../features/search/data/rx_search_user/rx.dart';
import '../features/search/model/all_user_response.dart';

/// Reactive data source for the sign-up (registration) request.
SignUpRx signupRx = SignUpRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

/// Reactive data source for verifying the sign-up OTP; emits a
/// [LoginResponse] (the session is established once the OTP is confirmed).
VerifySignupOtpRx verifySignupOtpRx = VerifySignupOtpRx(
  empty: LoginResponse(),
  dataFetcher: BehaviorSubject<LoginResponse>(),
);

/// Reactive data source for the logout request.
LogoutRx logoutRx = LogoutRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

/// Reactive data source for the login request; emits a [LoginResponse].
LoginRx loginRx = LoginRx(
  empty: LoginResponse(),
  dataFetcher: BehaviorSubject<LoginResponse>(),
);

/// Reactive data source for fetching the current user's profile.
GetProfileRx getProfileRx = GetProfileRx(
  empty: ProfileResponse(),
  dataFetcher: BehaviorSubject<ProfileResponse>(),
);

/// Reactive data source for updating the current user's profile.
EditProfileRx editProfileRx = EditProfileRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for changing the account password.
ChangePasswordRx changePasswordRx = ChangePasswordRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

// VerifyOtpRx verifyOtpRx = VerifyOtpRx(
//   empty: LoginResponse(),
//   dataFetcher: BehaviorSubject<LoginResponse>(),
// );

/// Reactive data source for requesting a forgot-password OTP.
ForgetPassRx forgetPassRx = ForgetPassRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for verifying the forgot-password OTP.
VerifyForgetPassRx verifyForgetPassRx = VerifyForgetPassRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

// ResendOtpRx resendOtpRx = ResendOtpRx(
//   empty: {},
//   dataFetcher: BehaviorSubject<Map>(),
// );

/// Reactive data source for resending the forgot-password OTP.
ResendForgetOtpRx resendForgetOtpRx = ResendForgetOtpRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for resetting the password after OTP verification.
ResetPasswordRx resetPasswordRx = ResetPasswordRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

// Friends

/// Reactive data source for searching users; emits an [AllUserResponse].
SearchUserRx searchUserRx = SearchUserRx(
  empty: AllUserResponse(),
  dataFetcher: BehaviorSubject<AllUserResponse>(),
);

/// Reactive data source for sending a friend request.
SendRequestRx sendRequestRx = SendRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for cancelling a sent friend request.
CancelRequestRx cancelRequestRx = CancelRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for declining an incoming friend request.
DeclineRequestRx declineRequestRx = DeclineRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for accepting an incoming friend request.
AcceptRequestRx acceptRequestRx = AcceptRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for the incoming friend requests; emits a
/// [GetRequestResponse].
GetRequestRx getRequestRx = GetRequestRx(
  empty: GetRequestResponse(),
  dataFetcher: BehaviorSubject<GetRequestResponse>(),
);

/// Reactive data source for the requests the user has sent; emits a
/// [GetRequestResponse].
GetSentRequestRx getSentRequestRx = GetSentRequestRx(
  empty: GetRequestResponse(),
  dataFetcher: BehaviorSubject<GetRequestResponse>(),
);

/// Reactive data source for the friend list; emits a [FriendListResponse].
GetFriendListRx getFriendListRx = GetFriendListRx(
  empty: FriendListResponse(),
  dataFetcher: BehaviorSubject<FriendListResponse>(),
);

/// Reactive data source for removing an existing friend.
UnfriendUserRx unfriendUserRx = UnfriendUserRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Block

/// Reactive data source for blocking a user.
BlockUserRx blockUserRx = BlockUserRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for the blocked-user list; emits a
/// [BlockListResponse].
GetBlockUserListRx getBlockUserListRx = GetBlockUserListRx(
  empty: BlockListResponse(),
  dataFetcher: BehaviorSubject<BlockListResponse>(),
);

/// Chatting

/// Reactive data source for the chat list; emits a [ChatListResponse].
GetAllChatRx getAllChatRx = GetAllChatRx(
  empty: ChatListResponse(),
  dataFetcher: BehaviorSubject<ChatListResponse>(),
);

/// Reactive data source for deleting chat messages.
DeleteMessageRx deleteMessageRx = DeleteMessageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for a one-to-one conversation; emits an
/// [InboxResponse].
GetInboxMessageRx getInboxMessageRx = GetInboxMessageRx(
  empty: InboxResponse(),
  dataFetcher: BehaviorSubject<InboxResponse>(),
);

/// Reactive data source for sending a one-to-one message. Also carries the
/// patent-flow `type: "reaction"` clip uploads.
SendMessageRx sendMessageRx = SendMessageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for the one-to-one `mark-viewed` call — the request
/// that, on success, triggers the patent-flow silent reaction recording.
ViewInboxImageRx viewInboxImageRx = ViewInboxImageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for a group conversation; emits a
/// [GroupInboxResponse].
GetGroupInboxRx getGroupInboxRx = GetGroupInboxRx(
  empty: GroupInboxResponse(),
  dataFetcher: BehaviorSubject<GroupInboxResponse>(),
);

// Group

/// Reactive data source for creating a group.
CreateGroupRx createGroupRx = CreateGroupRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for editing an existing group.
EditGroupRx editGroupRx = EditGroupRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for group details; emits a [GroupDetailsResponse].
GroupDetailsRx groupDetailsRx = GroupDetailsRx(
  empty: GroupDetailsResponse(),
  dataFetcher: BehaviorSubject<GroupDetailsResponse>(),
);

/// Reactive data source for a group's shared media; emits a
/// [GroupMediaResponse].
GetGroupMediaRx getGroupMediaRx = GetGroupMediaRx(
  empty: GroupMediaResponse(),
  dataFetcher: BehaviorSubject<GroupMediaResponse>(),
);

/// Reactive data source for sending a group message. Also carries the
/// patent-flow `type: "reaction"` clip uploads.
SendGroupMessageRx sendGroupMessageRx = SendGroupMessageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for promoting a group member to admin.
MakeGroupAdminRx makeGroupAdminRx = MakeGroupAdminRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for removing a member from a group.
RemoveMemberRx removeMemberRx = RemoveMemberRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for the privacy-policy content; emits a
/// [PrivacyResponse].
GetPrivacyRx getPrivacyRx = GetPrivacyRx(
  empty: PrivacyResponse(),
  dataFetcher: BehaviorSubject<PrivacyResponse>(),
);

/// Reactive data source for deleting the user's account.
DeleteAccountRx deleteAccountRx = DeleteAccountRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for registering the device's FCM push token.
AddTokenRx addTokenRx = AddTokenRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Reactive data source for the group `mark-viewed` call — the request that,
/// on success, triggers the patent-flow silent reaction recording.
ViewGroupFileRx viewGroupFileRx = ViewGroupFileRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);
