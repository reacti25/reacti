// ignore_for_file: constant_identifier_names

/// Single source of truth for the API base URL.
///
/// Resolved at build time from `--dart-define=BASE_URL=...`. With no define the
/// value falls back to the production host, so a plain `flutter build`/`run`
/// always targets production; only a deliberate define (e.g. the staging CI
/// build) points the app elsewhere.
const String url = String.fromEnvironment(
  "BASE_URL",
  defaultValue: "https://reacti.io/api",
);

final class NetworkConstants {
  NetworkConstants._();
  static const ACCEPT = "Accept";
  static const APP_KEY = "App-Key";
  static const ACCEPT_LANGUAGE = "Accept-Language";
  static const ACCEPT_LANGUAGE_VALUE = "pt";
  static const APP_KEY_VALUE = String.fromEnvironment("APP_KEY_VALUE");
  static const ACCEPT_TYPE = "application/json";
  static const AUTHORIZATION = "Authorization";
  static const CONTENT_TYPE = "content-Type";
}

final class EndPoints {
  EndPoints._();
  static String login() => "/login";
  static String signup() => "/register";
  static String verifySignupOtp() => "/email-verify";

  static String verifyOtp() => "/register-otp-verify";
  static String forgetPass() => "/forgot-password";
  static String verifyForgetPass() => "/verify-otp";
  static String resendOtp() => "/api/register";
  static String resendForgetOtp() => "/resend-otp";
  static String resetPassword() => "/reset-password";
  static String userProfile() => "/profile";
  static String addToken() => "/firebase/token/add";
  static String changePassword() => "/update-password";
  static String editProfile() => "/update-profile";
  static String logout() => "/logout";
  static String deleteAccount() => "/delete-profile";
  static String getPrivacy() => "/privacy-policy";
  static String getTerms() => "/terms-and-condition";
  static String getFaq() => "/faqs";

  // Friends Request
  static String searchUser(String query) => "/user-list?search=$query";

  static String sendRequest() => "/friends/send-request";
  static String cancelRequest() => "/friends/cancel-request";
  static String declineRequest() => "/friends/decline-request";
  static String acceptRequest() => "/friends/accept-request";

  static String getRequest() => "/friends/requests";
  static String getSentRequestList() => "/friends/requests/sent/list";
  static String getFriendList() => "/friends/list";

  static String unfriendUser(int id) => "/friends/unfriend/$id";

  // Report
  static String blockedUserList() => "/block/list";
  static String blockAUser(int id) => "/block/user/$id";

  static String chatList() => "/auth/chat/list";
  static String deleteMessage() => "/auth/chat/delete/chat/messages";
  static String inboxMessage(int id) => "/auth/chat/conversation/$id";
  static String sendMessage(int id) => "/auth/chat/send/$id";
  static String viewInboxImage(int id) => "/auth/chat/mark-viewed/$id";

  static String groupInbox(int id) => "/auth/group/$id/messages";
  static String viewGroupFile(int id) => "/auth/group/mark-viewed/$id";

  /// Group
  static String createGroup() => "/auth/group/create";
  static String editGroup(int id) => "/auth/group/$id/update";
  static String sendGroupMessage(int groupId) => "/auth/group/$groupId/send";
  static String groupDetails(int id) => "/auth/group/$id";
  static String groupMedia(int id) => "/auth/group/$id/messages/media";
  static String addGroupAdmin(int groupId, int userId) =>
      "/auth/group/$groupId/make-admin/$userId";

  static String removeMember(int groupId, int userId) =>
      "/auth/group/$groupId/remove-member/$userId";
}
