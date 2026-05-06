import 'package:achiar_expert_app/features/auth/model/login_response.dart';
import 'package:achiar_expert_app/features/chat/model/chat_list_response.dart';
import 'package:achiar_expert_app/features/chat/model/inbox_response.dart';
import 'package:achiar_expert_app/features/create_group/data/rx_create_group/rx.dart';
import 'package:achiar_expert_app/features/group_details/model/group_details_response.dart';
import 'package:achiar_expert_app/features/privacy/model/privacy_response.dart';
import 'package:achiar_expert_app/features/profile/data/rx_add_token/rx.dart';
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

SignUpRx signupRx = SignUpRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

VerifySignupOtpRx verifySignupOtpRx = VerifySignupOtpRx(
  empty: LoginResponse(),
  dataFetcher: BehaviorSubject<LoginResponse>(),
);

LogoutRx logoutRx = LogoutRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

LoginRx loginRx = LoginRx(
  empty: LoginResponse(),
  dataFetcher: BehaviorSubject<LoginResponse>(),
);

GetProfileRx getProfileRx = GetProfileRx(
  empty: ProfileResponse(),
  dataFetcher: BehaviorSubject<ProfileResponse>(),
);

EditProfileRx editProfileRx = EditProfileRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

ChangePasswordRx changePasswordRx = ChangePasswordRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

// VerifyOtpRx verifyOtpRx = VerifyOtpRx(
//   empty: LoginResponse(),
//   dataFetcher: BehaviorSubject<LoginResponse>(),
// );

ForgetPassRx forgetPassRx = ForgetPassRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

VerifyForgetPassRx verifyForgetPassRx = VerifyForgetPassRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

// ResendOtpRx resendOtpRx = ResendOtpRx(
//   empty: {},
//   dataFetcher: BehaviorSubject<Map>(),
// );

ResendForgetOtpRx resendForgetOtpRx = ResendForgetOtpRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

ResetPasswordRx resetPasswordRx = ResetPasswordRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

// Friends

SearchUserRx searchUserRx = SearchUserRx(
  empty: AllUserResponse(),
  dataFetcher: BehaviorSubject<AllUserResponse>(),
);

SendRequestRx sendRequestRx = SendRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

CancelRequestRx cancelRequestRx = CancelRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

DeclineRequestRx declineRequestRx = DeclineRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

AcceptRequestRx acceptRequestRx = AcceptRequestRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

GetRequestRx getRequestRx = GetRequestRx(
  empty: GetRequestResponse(),
  dataFetcher: BehaviorSubject<GetRequestResponse>(),
);

GetSentRequestRx getSentRequestRx = GetSentRequestRx(
  empty: GetRequestResponse(),
  dataFetcher: BehaviorSubject<GetRequestResponse>(),
);

GetFriendListRx getFriendListRx = GetFriendListRx(
  empty: FriendListResponse(),
  dataFetcher: BehaviorSubject<FriendListResponse>(),
);

UnfriendUserRx unfriendUserRx = UnfriendUserRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

/// Block

BlockUserRx blockUserRx = BlockUserRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

GetBlockUserListRx getBlockUserListRx = GetBlockUserListRx(
  empty: BlockListResponse(),
  dataFetcher: BehaviorSubject<BlockListResponse>(),
);

/// Chatting

GetAllChatRx getAllChatRx = GetAllChatRx(
  empty: ChatListResponse(),
  dataFetcher: BehaviorSubject<ChatListResponse>(),
);

DeleteMessageRx deleteMessageRx = DeleteMessageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

GetInboxMessageRx getInboxMessageRx = GetInboxMessageRx(
  empty: InboxResponse(),
  dataFetcher: BehaviorSubject<InboxResponse>(),
);

SendMessageRx sendMessageRx = SendMessageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

ViewInboxImageRx viewInboxImageRx = ViewInboxImageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

GetGroupInboxRx getGroupInboxRx = GetGroupInboxRx(
  empty: GroupInboxResponse(),
  dataFetcher: BehaviorSubject<GroupInboxResponse>(),
);

// Group

CreateGroupRx createGroupRx = CreateGroupRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

EditGroupRx editGroupRx = EditGroupRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

GroupDetailsRx groupDetailsRx = GroupDetailsRx(
  empty: GroupDetailsResponse(),
  dataFetcher: BehaviorSubject<GroupDetailsResponse>(),
);

GetGroupMediaRx getGroupMediaRx = GetGroupMediaRx(
  empty: GroupMediaResponse(),
  dataFetcher: BehaviorSubject<GroupMediaResponse>(),
);

SendGroupMessageRx sendGroupMessageRx = SendGroupMessageRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

MakeGroupAdminRx makeGroupAdminRx = MakeGroupAdminRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

RemoveMemberRx removeMemberRx = RemoveMemberRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

GetPrivacyRx getPrivacyRx = GetPrivacyRx(
  empty: PrivacyResponse(),
  dataFetcher: BehaviorSubject<PrivacyResponse>(),
);

DeleteAccountRx deleteAccountRx = DeleteAccountRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

AddTokenRx addTokenRx = AddTokenRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);

ViewGroupFileRx viewGroupFileRx = ViewGroupFileRx(
  empty: {},
  dataFetcher: BehaviorSubject<Map>(),
);
