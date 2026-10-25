import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/auth/presentation/forgot_pass/forgot_password_screen.dart';
import 'package:reacti_app/features/auth/presentation/login/login_screen.dart';
import 'package:reacti_app/features/auth/presentation/reset_pass/reset_password_screen.dart';
import 'package:reacti_app/features/auth/presentation/signup/signup_screen.dart';
import 'package:reacti_app/features/auth/presentation/signup_verify_otp/signup_verify_otp_screen.dart';
import 'package:reacti_app/features/auth/presentation/verify_otp/verify_otp_screen.dart';
import 'package:reacti_app/features/analytics_settings/presentation/analytics_settings_screen.dart';
import 'package:reacti_app/features/block/presentation/block_screen.dart';
import 'package:reacti_app/features/change_password/presentation/change_password_screen.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/features/create_group/presentation/create_group_screen.dart';
import 'package:reacti_app/features/edit_group/presentation/edit_group_screen.dart';
import 'package:reacti_app/features/edit_profile/presentation/edit_profile_screen.dart';
import 'package:reacti_app/features/group_details/presentation/group_details_screen.dart';
import 'package:reacti_app/features/group_member/presentation/add_member_screen.dart';
import 'package:reacti_app/features/navigation/presentation/navigation_screen.dart';
import 'package:reacti_app/features/permission/presentation/permission_list_screen.dart';
import 'package:reacti_app/features/privacy/presentation/privacy_screen.dart';
import 'package:reacti_app/features/profile/presentation/appearance_settings_screen.dart';
import 'package:reacti_app/features/profile/presentation/read_receipts_settings_screen.dart';
import 'package:reacti_app/features/profile/presentation/settings_screen.dart';
import 'package:reacti_app/features/profile/presentation/sound_vibration_settings_screen.dart';
import 'package:reacti_app/features/report/presentation/report_screen.dart';
import 'package:reacti_app/features/search/presentation/search_screen.dart';
import 'package:reacti_app/features/terms/presentation/terms_screen.dart';
import 'package:reacti_app/helpers/all_routes.dart';

/// Pins [RouteGenerator.generateRoute]: every named route builds its screen,
/// arguments reach the constructor, and unknown names return null.
///
/// Tests run on a desktop host, so `Platform.isAndroid` is false and the
/// iOS branch ([CupertinoPageRoute]) is the one exercised.
void main() {
  final cases = <String, (Type, Map<String, dynamic>?)>{
    Routes.navigationScreen: (NavigationScreen, null),
    Routes.loginScreen: (LoginScreen, null),
    Routes.signupScreen: (SignupScreen, null),
    Routes.signupVerifyOtpRoute: (SignupVerifyOtpScreen, {'email': 'a@b.c'}),
    Routes.inboxRoute: (
      InboxScreen,
      {'id': 1, 'roomId': 2, 'name': 'n', 'image': 'i'},
    ),
    Routes.forgetPassRoute: (ForgotPasswordScreen, null),
    Routes.groupInboxRoute: (
      GroupInboxScreen,
      {'roomId': 2, 'name': 'g', 'groupImage': 'x'},
    ),
    Routes.editGroupRoute: (EditGroupScreen, {'groupId': 3}),
    Routes.groupDetailsRoute: (GroupDetailsScreen, {'id': 3}),
    Routes.addMemberRoute: (AddMemberScreen, {'groupId': 3}),
    Routes.editProfileRoute: (EditProfileScreen, null),
    Routes.privacyRoute: (PrivacyScreen, null),
    Routes.analyticsSettingsRoute: (AnalyticsSettingsScreen, null),
    Routes.readReceiptsRoute: (ReadReceiptsSettingsScreen, null),
    Routes.soundVibrationRoute: (SoundVibrationSettingsScreen, null),
    Routes.appearanceRoute: (AppearanceSettingsScreen, null),
    Routes.settingsRoute: (SettingsScreen, null),
    Routes.termsRoute: (TermsScreen, null),
    Routes.changePasswordRoute: (ChangePasswordScreen, null),
    Routes.createGroupRoute: (CreateGroupScreen, null),
    Routes.reportUserRoute: (ReportScreen, {'name': 'n'}),
    Routes.blockRoute: (BlockScreen, null),
    Routes.verifyOtpRoute: (VerifyOtpScreen, {'email': 'a@b.c'}),
    Routes.resetPassScreen: (
      ResetPasswordScreen,
      {'email': 'a@b.c', 'token': 't'},
    ),
    Routes.searchRoute: (SearchScreen, null),
    Routes.permissionRoute: (PermissionListScreen, null),
  };

  testWidgets('every named route builds its screen', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    for (final MapEntry(key: name, value: (type, args)) in cases.entries) {
      final route = RouteGenerator.generateRoute(
        RouteSettings(name: name, arguments: args),
      );
      expect(route, isA<CupertinoPageRoute<dynamic>>(), reason: name);
      // Analytics reads the screen name from here; iOS once had none.
      expect(route!.settings.name, name, reason: name);
      final screen = (route as CupertinoPageRoute<dynamic>).builder(context);
      expect(screen.runtimeType, type, reason: name);
    }
  });

  testWidgets('arguments reach the screen constructor', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    Widget build(String name, Map<String, dynamic> args) =>
        (RouteGenerator.generateRoute(
                  RouteSettings(name: name, arguments: args),
                )!
                as CupertinoPageRoute<dynamic>)
            .builder(context);

    final inbox =
        build(Routes.inboxRoute, {
              'id': 7,
              'roomId': 8,
              'name': 'Ann',
              'image': 'u',
            })
            as InboxScreen;
    expect(
      [inbox.id, inbox.roomId, inbox.name, inbox.image],
      [7, 8, 'Ann', 'u'],
    );

    final group =
        build(Routes.groupInboxRoute, {
              'roomId': 9,
              'name': 'G',
              'groupImage': 'g',
            })
            as GroupInboxScreen;
    expect([group.roomId, group.name, group.groupImage], [9, 'G', 'g']);

    final reset =
        build(Routes.resetPassScreen, {'email': 'e', 'token': 't'})
            as ResetPasswordScreen;
    expect([reset.email, reset.token], ['e', 't']);
  });

  test('every Routes constant is covered and unknown names return null', () {
    expect(cases.length, 26);
    expect(
      RouteGenerator.generateRoute(const RouteSettings(name: '/nope')),
      isNull,
    );
  });
}
