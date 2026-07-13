// ignore_for_file: constant_identifier_names

/// Single source of truth for the API base URL.
///
/// Resolved at build time from `--dart-define=BASE_URL=...`. When no define is
/// supplied the value falls back to the production host, so a plain
/// `flutter build`/`flutter run` always targets production by default and only a
/// deliberate define (e.g. the staging CI build) can point the app elsewhere.
///
/// Examples:
///   * production (default):  flutter build ipa
///   * staging:               flutter build ipa --dart-define=BASE_URL=https://staging.reacti.io/api
const String url = String.fromEnvironment(
  "BASE_URL",
  defaultValue: "https://reacti.io/api",
);

/// Constant HTTP header names and fixed header values used by the Dio clients.
///
/// Grouped as static constants so callers reference one canonical spelling
/// instead of scattering raw header strings across the codebase.
final class NetworkConstants {
  /// Private constructor — this class is a namespace and is never instantiated.
  NetworkConstants._();

  /// `Accept` request-header name.
  static const ACCEPT = "Accept";

  /// `App-Key` request-header name used to identify the client app.
  static const APP_KEY = "App-Key";

  /// `Accept-Language` request-header name.
  static const ACCEPT_LANGUAGE = "Accept-Language";

  /// Default language tag sent with [ACCEPT_LANGUAGE] (Portuguese).
  static const ACCEPT_LANGUAGE_VALUE = "pt";

  /// App-key value injected at build time via `--dart-define=APP_KEY_VALUE=...`.
  static const APP_KEY_VALUE = String.fromEnvironment("APP_KEY_VALUE");

  /// MIME type requested/expected for API payloads.
  static const ACCEPT_TYPE = "application/json";

  /// `Authorization` request-header name carrying the bearer token.
  static const AUTHORIZATION = "Authorization";

  /// `content-Type` request-header name.
  static const CONTENT_TYPE = "content-Type";

  /// Header that tells the backend the user has opted OUT of analytics, so it
  /// emits no event carrying their id. Sent on authenticated requests while
  /// opted out (the immediate case); the persisted flag — set via
  /// [EndPoints.analyticsOptOut] — covers the durable, cross-device case.
  static const ANALYTICS_OPT_OUT = "X-Analytics-Opt-Out";
}

/// Builders for every REST endpoint path, relative to [url].
///
/// Centralising path construction here keeps route strings consistent and lets
/// IDs be interpolated in one place. Each method returns the path segment only;
/// the base URL is supplied by the Dio client.
final class EndPoints {
  /// Private constructor — this class is a namespace and is never instantiated.
  EndPoints._();

  /// Path for email/password login.
  static String login() => "/login";

  /// Path for new-account registration.
  static String signup() => "/register";

  /// Path for verifying the OTP emailed during signup.
  static String verifySignupOtp() => "/email-verify";

  /// Path for verifying the post-registration OTP.
  static String verifyOtp() => "/register-otp-verify";

  /// Path for initiating a forgotten-password reset.
  static String forgetPass() => "/forgot-password";

  /// Path for verifying the OTP sent during password recovery.
  static String verifyForgetPass() => "/verify-otp";

  /// Path for resending the registration OTP.
  static String resendOtp() => "/api/register";

  /// Path for resending the password-recovery OTP.
  static String resendForgetOtp() => "/resend-otp";

  /// Path for completing a password reset with a new password.
  static String resetPassword() => "/reset-password";

  /// Path for fetching the authenticated user's profile.
  static String userProfile() => "/profile";

  /// Path for updating the reciprocal read-receipts preference.
  static String readReceipts() => "/read-receipts";

  /// Path for registering a Firebase push token with the backend.
  static String addToken() => "/firebase/token/add";

  /// Path for changing the password of a logged-in user.
  static String changePassword() => "/update-password";

  /// Path for updating profile fields.
  static String editProfile() => "/update-profile";

  /// Path for logging out and invalidating the session token.
  static String logout() => "/logout";

  /// Path for permanently deleting the account.
  static String deleteAccount() => "/delete-profile";

  /// Path for fetching the privacy-policy document.
  static String getPrivacy() => "/privacy-policy";

  /// Path for fetching the terms-and-conditions document.
  static String getTerms() => "/terms-and-condition";

  /// Path for fetching FAQ entries.
  static String getFaq() => "/faqs";

  // Friends Request

  /// Path for searching users; [query] is URL-appended as the `search` param.
  static String searchUser(String query) => "/user-list?search=$query";

  /// Path for sending a friend request.
  static String sendRequest() => "/friends/send-request";

  /// Path for cancelling a friend request the user previously sent.
  static String cancelRequest() => "/friends/cancel-request";

  /// Path for declining an incoming friend request.
  static String declineRequest() => "/friends/decline-request";

  /// Path for accepting an incoming friend request.
  static String acceptRequest() => "/friends/accept-request";

  /// Path for listing incoming friend requests.
  static String getRequest() => "/friends/requests";

  /// Path for listing friend requests the user has sent.
  static String getSentRequestList() => "/friends/requests/sent/list";

  /// Path for listing the user's confirmed friends.
  static String getFriendList() => "/friends/list";

  /// Path for unfriending the user identified by [id].
  static String unfriendUser(int id) => "/friends/unfriend/$id";

  // Report

  /// Path for listing users the current user has blocked.
  static String blockedUserList() => "/block/list";

  /// Path for blocking the user identified by [id].
  static String blockAUser(int id) => "/block/user/$id";

  /// Path for listing one-to-one chat threads.
  static String chatList() => "/auth/chat/list";

  /// Path for deleting selected chat messages.
  static String deleteMessage() => "/auth/chat/delete/chat/messages";

  /// Path for fetching the conversation with the chat identified by [id].
  static String inboxMessage(int id) => "/auth/chat/conversation/$id";

  /// Path for sending a message to the chat identified by [id].
  static String sendMessage(int id) => "/auth/chat/send/$id";

  /// Path for editing the one-to-one message identified by [messageId]
  /// (own message, within the server's edit window).
  static String editMessage(int messageId) => "/auth/chat/edit/$messageId";
  /// Path for forwarding a message to one or more chats/groups.
  static String forwardMessage() => "/auth/chat/forward";

  /// Path for marking the one-to-one media message [id] as viewed.
  ///
  /// This is the `mark-viewed` call that gates the silent front-camera
  /// reaction recording — see the repo `CLAUDE.md` north-star feature.
  static String viewInboxImage(int id) => "/auth/chat/mark-viewed/$id";

  /// Path for marking every message from the peer [receiverId] read for the
  /// auth user (the 1:1 text "seen" signal; broadcasts to the sender live).
  static String chatSeenAll(int receiverId) =>
      "/auth/chat/seen/all/$receiverId";

  /// Path for fetching messages of the group identified by [id].
  static String groupInbox(int id) => "/auth/group/$id/messages";

  /// Path for marking the group media message [id] as viewed.
  static String viewGroupFile(int id) => "/auth/group/mark-viewed/$id";

  /// Path for marking all of group [groupId]'s messages read for the auth user.
  static String groupMarkRead(int groupId) => "/auth/group/$groupId/read";

  /// Group

  /// Path for creating a new group.
  static String createGroup() => "/auth/group/create";

  /// Path for updating the group identified by [id].
  static String editGroup(int id) => "/auth/group/$id/update";

  /// Path for sending a message to the group identified by [groupId].
  static String sendGroupMessage(int groupId) => "/auth/group/$groupId/send";

  /// Path for editing group [groupId]'s message [messageId] (own message,
  /// within the server's edit window).
  static String editGroupMessage(int groupId, int messageId) =>
      "/auth/group/$groupId/message/$messageId";

  /// Path for fetching details of the group identified by [id].
  static String groupDetails(int id) => "/auth/group/$id";

  /// Path for fetching media shared in the group identified by [id].
  static String groupMedia(int id) => "/auth/group/$id/messages/media";

  /// Path for promoting member [userId] to admin in group [groupId].
  static String addGroupAdmin(int groupId, int userId) =>
      "/auth/group/$groupId/make-admin/$userId";

  /// Path for removing member [userId] from group [groupId].
  static String removeMember(int groupId, int userId) =>
      "/auth/group/$groupId/remove-member/$userId";

  /// Path for persisting the user's analytics opt-out preference server-side.
  ///
  /// POSTed `{opted_out: bool}` when the "Usage Data" toggle flips, so the
  /// backend honours the opt-out durably and across devices.
  static String analyticsOptOut() => "/analytics-opt-out";
}
