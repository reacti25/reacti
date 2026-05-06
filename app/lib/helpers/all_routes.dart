// ignore_for_file: unused_element

import 'dart:io';

import 'package:achiar_expert_app/features/auth/presentation/forgot_pass/forgot_password_screen.dart';
import 'package:achiar_expert_app/features/auth/presentation/reset_pass/reset_password_screen.dart';
import 'package:achiar_expert_app/features/auth/presentation/signup/signup_screen.dart';
import 'package:achiar_expert_app/features/auth/presentation/verify_otp/verify_otp_screen.dart';
import 'package:achiar_expert_app/features/block/presentation/block_screen.dart';
import 'package:achiar_expert_app/features/change_password/presentation/change_password_screen.dart';
import 'package:achiar_expert_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:achiar_expert_app/features/chat/presentation/inbox_screen.dart';
import 'package:achiar_expert_app/features/create_group/presentation/create_group_screen.dart';
import 'package:achiar_expert_app/features/edit_group/presentation/edit_group_screen.dart';
import 'package:achiar_expert_app/features/edit_profile/presentation/edit_profile_screen.dart';
import 'package:achiar_expert_app/features/group_details/presentation/group_details_screen.dart';
import 'package:achiar_expert_app/features/navigation/presentation/navigation_screen.dart';
import 'package:achiar_expert_app/features/permission/presentation/permission_list_screen.dart';
import 'package:achiar_expert_app/features/privacy/presentation/privacy_screen.dart';
import 'package:achiar_expert_app/features/report/presentation/report_screen.dart';
import 'package:achiar_expert_app/features/search/presentation/search_screen.dart';
import 'package:achiar_expert_app/features/sent_request/presentation/sent_request_screen.dart';
import 'package:achiar_expert_app/features/terms/presentation/terms_screen.dart';
import 'package:flutter/cupertino.dart';

import '../features/auth/presentation/login/login_screen.dart';
import '../features/auth/presentation/signup_verify_otp/signup_verify_otp_screen.dart';
import '../features/group_member/presentation/add_member_Screen.dart';

final class Routes {
  static final Routes _routes = Routes._internal();
  Routes._internal();
  static Routes get instance => _routes;

  static const String navigationScreen = '/navigation_screen';

  static const String loginScreen = '/login_screen';
  static const String signupScreen = '/signup_screen';
  static const String signupVerifyOtpRoute = '/signupVerifyOtpRoute';
  static const String forgetPassRoute = '/forget_pass_screen';
  static const String verifyOtpRoute = '/verify_otp_screen';
  static const String verifySignupOtpRoute = '/verify_signup_otp_screen';
  static const String resetPassRoute = '/reset_pass_screen';
  static const String privacyRoute = '/privacy_screen';
  static const String termsRoute = '/terms_screen';

  static const String createPostScreen = '/createPostScreen';

  static const String editScreen = '/editScreen';

  static const String resetPassScreen = '/resetPassScreen';
  static const String searchRoute = '/searchScreen';
  static const String inboxRoute = '/inboxScreen';
  static const String groupInboxRoute = '/groupInboxScreen';
  static const String groupDetailsRoute = '/groupDetailsScreen';
  static const String editProfileRoute = '/edit_profile_screen';
  static const String changePasswordRoute = '/change_password_screen';
  static const String permissionRoute = '/permission_screen';
  static const String createGroupRoute = '/create_group_screen';
  static const String reportUserRoute = '/report_user_screen';
  static const String blockRoute = '/block_screen';
  static const String sentRequestRoute = '/sent_request_screen';
  static const String addMemberRoute = '/add_member_screen';
  static const String editGroupRoute = '/edit_group_screen';
}

final class RouteGenerator {
  static final RouteGenerator _routeGenerator = RouteGenerator._internal();
  RouteGenerator._internal();
  static RouteGenerator get instance => _routeGenerator;

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

class _FadedTransitionRoute extends PageRouteBuilder {
  final Widget widget;
  @override
  final RouteSettings settings;

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

class ScreenTitle extends StatelessWidget {
  final Widget widget;

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
