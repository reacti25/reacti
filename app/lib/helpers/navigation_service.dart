// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';

/// Context-free navigation facade backed by a global [navigatorKey].
///
/// Lets non-widget code (services, providers, helpers) trigger navigation
/// without holding a [BuildContext]. The [navigatorKey] must be attached to
/// the app's `MaterialApp` for any of these methods to work.
final class NavigationService {
  NavigationService._();

  /// Global navigator key wired into `MaterialApp.navigatorKey`.
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Pushes the route named [routeName] onto the navigator stack.
  static Future<dynamic> navigateTo(String routeName) =>
      navigatorKey.currentState!.pushNamed(routeName);

  /// Pushes [routeName] and clears the entire prior navigation stack.
  ///
  /// Useful after auth transitions where the user must not be able to go back.
  static Future<dynamic> navigateToReplacementUntil(String routeName) =>
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        routeName,
        (Route<dynamic> route) => false,
      );

  /// Pushes [routeName], forwarding [map] as the route's arguments.
  static Future<dynamic> navigateToWithArgs(
    String routeName,
    Map<String, dynamic>? map,
  ) => navigatorKey.currentState!.pushNamed(routeName, arguments: map);

  /// Pops the current route off the navigator stack.
  static get goBack => navigatorKey.currentState!.pop();

  /// The current [BuildContext] of the global navigator, if available.
  static get context => navigatorKey.currentContext;
}
