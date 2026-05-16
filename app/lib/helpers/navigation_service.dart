// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';

/// Context-free navigation facade backed by a global [navigatorKey].
///
/// Lets non-widget code (services, providers, helpers) trigger navigation
/// without holding a [BuildContext]. The [navigatorKey] must be attached to
/// the app's `MaterialApp` for any of these methods to work.
final class NavigationService {
  /// The single shared [NavigationService] instance backing [instance].
  static final NavigationService _navigationService =
      NavigationService._internal();

  /// Private constructor enforcing the singleton pattern.
  NavigationService._internal();

  /// Returns the shared [NavigationService] singleton.
  static NavigationService get instance => _navigationService;

  /// Global navigator key wired into `MaterialApp.navigatorKey`.
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Pushes the route named [routeName] onto the navigator stack.
  static Future<dynamic> navigateTo(String routeName) =>
      navigatorKey.currentState!.pushNamed(routeName);

  /// Replaces the current route with the one named [routeName].
  static Future<dynamic> navigateToReplacement(String routeName) =>
      navigatorKey.currentState!.pushReplacementNamed(routeName);

  /// Pops the current route, then pushes [routeName] in its place.
  static Future<dynamic> popAndReplace(String routeName) async {
    return await navigatorKey.currentState!.popAndPushNamed(routeName);
  }

  /// Pushes [routeName] and clears the entire prior navigation stack.
  ///
  /// Useful after auth transitions where the user must not be able to go back.
  static Future<dynamic> navigateToReplacementUntil(
    String routeName,
  ) =>
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        routeName,
        (Route<dynamic> route) => false,
      );

  /// Pushes [routeName], forwarding [map] as the route's arguments.
  static Future<dynamic> navigateToWithArgs(
    String routeName,
    Map<String, dynamic>? map,
  ) =>
      navigatorKey.currentState!.pushNamed(routeName, arguments: map);

  /// Pops the current route, then pushes [routeName] with [map] as arguments.
  static Future<dynamic> popAndReplaceWihArgs(
          String routeName, Map<String, dynamic>? map) =>
      navigatorKey.currentState!.popAndPushNamed(routeName, arguments: map);

  /// Pushes [routeName], forwarding an arbitrary [obj] as the route argument.
  static Future<dynamic> navigateToWithObject(
    String routeName,
    Object? obj,
  ) =>
      navigatorKey.currentState!.pushNamed(routeName, arguments: obj);

  /// Pops the current route off the navigator stack.
  static get goBack => navigatorKey.currentState!.pop();

  /// Whether the navigator can pop a route (i.e. a back action is possible).
  static get goBeBack => navigatorKey.currentState!.canPop();

  /// The current [BuildContext] of the global navigator, if available.
  static get context => navigatorKey.currentContext;
}
