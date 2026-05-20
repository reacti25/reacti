// ignore_for_file: unused_element

import 'dart:io';

import 'package:reacti_app/features/auth/presentation/forgot_pass/forgot_password_screen.dart';
import 'package:reacti_app/features/auth/presentation/reset_pass/reset_password_screen.dart';
import 'package:reacti_app/features/auth/presentation/signup/signup_screen.dart';
import 'package:reacti_app/features/auth/presentation/verify_otp/verify_otp_screen.dart';
import 'package:reacti_app/features/block/presentation/block_screen.dart';
import 'package:reacti_app/features/change_password/presentation/change_password_screen.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/features/create_group/presentation/create_group_screen.dart';
import 'package:reacti_app/features/edit_group/presentation/edit_group_screen.dart';
import 'package:reacti_app/features/edit_profile/presentation/edit_profile_screen.dart';
import 'package:reacti_app/features/group_details/presentation/group_details_screen.dart';
import 'package:reacti_app/features/navigation/presentation/navigation_screen.dart';
import 'package:reacti_app/features/permission/presentation/permission_list_screen.dart';
import 'package:reacti_app/features/privacy/presentation/privacy_screen.dart';
import 'package:reacti_app/features/report/presentation/report_screen.dart';
import 'package:reacti_app/features/search/presentation/search_screen.dart';
import 'package:reacti_app/features/sent_request/presentation/sent_request_screen.dart';
import 'package:reacti_app/features/terms/presentation/terms_screen.dart';
import 'package:flutter/cupertino.dart';

import '../features/auth/presentation/login/login_screen.dart';
import '../features/auth/presentation/signup_verify_otp/signup_verify_otp_screen.dart';
import '../features/group_member/presentation/add_member_screen.dart';

/// Central registry of named route strings used throughout the app.
///
/// Exists so screen navigation references symbolic constants instead of
/// loose string literals, keeping route names consistent and refactor-safe.
/// Implemented as a singleton, though the route names are static constants
/// and can be referenced without an instance.
final class Routes {
  /// The single shared [Routes] instance backing [instance].
  static final Routes _routes = Routes._internal();

  /// Private constructor enforcing the singleton pattern.
  Routes._internal();

  /// Returns the shared [Routes] singleton.
  static Routes get instance => _routes;

  /// Route for the main bottom-navigation host screen.
  static const String navigationScreen = '/navigation_screen';

  /// Route for the login screen.
  static const String loginScreen = '/login_screen';

  /// Route for the account sign-up screen.
  static const String signupScreen = '/signup_screen';

  /// Route for the OTP verification step that follows sign-up.
  static const String signupVerifyOtpRoute = '/signupVerifyOtpRoute';

  /// Route for the forgot-password screen.
  static const String forgetPassRoute = '/forget_pass_screen';

  /// Route for verifying the OTP sent during password recovery.
  static const String verifyOtpRoute = '/verify_otp_screen';

  /// Route for verifying the OTP sent during sign-up (legacy alias).
  static const String verifySignupOtpRoute = '/verify_signup_otp_screen';

  /// Route for the reset-password screen.
  static const String resetPassRoute = '/reset_pass_screen';

  /// Route for the privacy policy screen.
  static const String privacyRoute = '/privacy_screen';

  /// Route for the terms-of-service screen.
  static const String termsRoute = '/terms_screen';

  /// Route for the create-post screen (currently unused by [RouteGenerator]).
  static const String createPostScreen = '/createPostScreen';

  /// Generic edit screen route (currently unused by [RouteGenerator]).
  static const String editScreen = '/editScreen';

  /// Route for the reset-password screen reached via a recovery token.
  static const String resetPassScreen = '/resetPassScreen';

  /// Route for the user/group search screen.
  static const String searchRoute = '/searchScreen';

  /// Route for the one-to-one chat inbox screen.
  static const String inboxRoute = '/inboxScreen';

  /// Route for the group chat inbox screen.
  static const String groupInboxRoute = '/groupInboxScreen';

  /// Route for the group details screen.
  static const String groupDetailsRoute = '/groupDetailsScreen';

  /// Route for the edit-profile screen.
  static const String editProfileRoute = '/edit_profile_screen';

  /// Route for the change-password screen.
  static const String changePasswordRoute = '/change_password_screen';

  /// Route for the permission list screen.
  static const String permissionRoute = '/permission_screen';

  /// Route for the create-group screen.
  static const String createGroupRoute = '/create_group_screen';

  /// Route for the report-user screen.
  static const String reportUserRoute = '/report_user_screen';

  /// Route for the blocked-users screen.
  static const String blockRoute = '/block_screen';

  /// Route for the sent friend-requests screen.
  static const String sentRequestRoute = '/sent_request_screen';

  /// Route for the add-member-to-group screen.
  static const String addMemberRoute = '/add_member_screen';

  /// Route for the edit-group screen.
  static const String editGroupRoute = '/edit_group_screen';
}

/// Builds [Route] objects for the named routes declared in [Routes].
///
/// Wired into `MaterialApp.onGenerateRoute` so every `Navigator.pushNamed`
/// call resolves to the correct screen. Android routes use a custom fade
/// transition while iOS uses the native [CupertinoPageRoute] for a
/// platform-consistent feel.
final class RouteGenerator {
  /// The single shared [RouteGenerator] instance backing [instance].
  static final RouteGenerator _routeGenerator = RouteGenerator._internal();

  /// Private constructor enforcing the singleton pattern.
  RouteGenerator._internal();

  /// Returns the shared [RouteGenerator] singleton.
  static RouteGenerator get instance => _routeGenerator;

  /// Resolves [settings] into a concrete [Route] for the requested screen.
  ///
  /// Matches `settings.name` against the constants in [Routes], extracting
  /// any `settings.arguments` map to forward into the target screen's
  /// constructor. Returns `null` for unrecognised route names so the
  /// navigator can apply its default unknown-route handling.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.navigationScreen:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const NavigationScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => const NavigationScreen(),
            );

      case Routes.loginScreen:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const LoginScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => const LoginScreen());

      case Routes.signupScreen:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const SignupScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => const SignupScreen());

      case Routes.signupVerifyOtpRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: SignupVerifyOtpScreen(email: args?['email']),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder:
                  (context) => SignupVerifyOtpScreen(email: args?['email']),
            );

      case Routes.inboxRoute:
        final args = settings.arguments as Map?;

        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: InboxScreen(
                id: args?['id'],
                roomId: args?['roomId'],
                name: args?['name'],
                image: args?['image'],
              ),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder:
                  (context) => InboxScreen(
                    id: args?['id'],
                    roomId: args?['roomId'],
                    name: args?['name'],
                    image: args?['image'],
                  ),
            );

      case Routes.forgetPassRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const ForgotPasswordScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => const ForgotPasswordScreen(),
            );

      case Routes.groupInboxRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: GroupInboxScreen(
                roomId: args?['roomId'],
                name: args?['name'],
                groupImage: args?['groupImage'],
              ),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder:
                  (context) => GroupInboxScreen(
                    roomId: args?['roomId'],
                    name: args?['name'],
                    groupImage: args?['groupImage'],
                  ),
            );

      case Routes.editGroupRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: EditGroupScreen(groupId: args?['groupId']),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => EditGroupScreen(groupId: args?['groupId']),
            );

      case Routes.groupDetailsRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: GroupDetailsScreen(id: args?['id']),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => GroupDetailsScreen(id: args?['id']),
            );

      case Routes.addMemberRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: AddMemberScreen(groupId: args?['groupId']),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => AddMemberScreen(groupId: args?['groupId']),
            );

      case Routes.editProfileRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const EditProfileScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => const EditProfileScreen(),
            );

      case Routes.privacyRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const PrivacyScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => const PrivacyScreen());

      case Routes.termsRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const TermsScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => const TermsScreen());

      case Routes.changePasswordRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const ChangePasswordScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => const ChangePasswordScreen(),
            );

      case Routes.createGroupRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const CreateGroupScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => const CreateGroupScreen(),
            );

      case Routes.reportUserRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: ReportScreen(name: args?['name']),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => ReportScreen(name: args?['name']),
            );

      case Routes.blockRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: const BlockScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => const BlockScreen());

      // case Routes.forgetPassRoute:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //         widget: const ForgetPasswordScreen(),
      //         settings: settings,
      //       )
      //       : CupertinoPageRoute(
      //         builder: (context) => const ForgetPasswordScreen(),
      //       );

      // case Routes.verifySignupOtpRoute:
      //   final args = settings.arguments as Map?;
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //         widget: VerifyOtpScreen(email: args?['email']),
      //         settings: settings,
      //       )
      //       : CupertinoPageRoute(
      //         builder: (context) => VerifyOtpScreen(email: args?['email']),
      //       );

      case Routes.verifyOtpRoute:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: VerifyOtpScreen(email: args?['email']),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder: (context) => VerifyOtpScreen(email: args?['email']),
            );

      case Routes.resetPassScreen:
        final args = settings.arguments as Map?;
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: ResetPasswordScreen(
                email: args?['email'],
                token: args?['token'],
              ),
              settings: settings,
            )
            : CupertinoPageRoute(
              builder:
                  (context) => ResetPasswordScreen(
                    email: args?['email'],
                    token: args?['token'],
                  ),
            );

      case Routes.searchRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(widget: SearchScreen(), settings: settings)
            : CupertinoPageRoute(builder: (context) => SearchScreen());

      case Routes.sentRequestRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: SentRequestScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => SentRequestScreen());

      case Routes.permissionRoute:
        return Platform.isAndroid
            ? _FadedTransitionRoute(
              widget: PermissionListScreen(),
              settings: settings,
            )
            : CupertinoPageRoute(builder: (context) => PermissionListScreen());

      default:
        return null;
    }
  }
}

/// A near-instant fade [PageRoute] used for Android screen transitions.
///
/// Wraps a target [widget] in a [FadeTransition] with a 1ms duration so
/// navigation feels immediate while still avoiding an abrupt hard cut.
class _FadedTransitionRoute extends PageRouteBuilder {
  /// The screen widget this route displays.
  final Widget widget;

  /// The route settings (name and arguments) carried by this route.
  @override
  final RouteSettings settings;

  /// Creates a fade route that presents [widget] for the given [settings].
  _FadedTransitionRoute({required this.widget, required this.settings})
    : super(
        settings: settings,
        reverseTransitionDuration: const Duration(milliseconds: 1),
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return widget;
        },
        transitionDuration: const Duration(milliseconds: 1),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.ease),
            child: child,
          );
        },
      );
}

/// Wraps a child in a one-shot fade-and-scale entrance animation.
///
/// Reused for screen headings/titles that should animate into view when a
/// screen first builds. The [widget] parameter is the content to animate.
class ScreenTitle extends StatelessWidget {
  /// The content displayed once the entrance animation completes.
  final Widget widget;

  /// Creates a [ScreenTitle] that animates [widget] into view.
  const ScreenTitle({super.key, required this.widget});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: .5, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.bounceIn,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: widget,
    );
  }
}
