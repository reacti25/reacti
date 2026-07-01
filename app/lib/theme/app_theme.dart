import 'package:reacti_app/constants/custom_theme.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';

/// The app's two [ThemeData] objects, selected at runtime by [ThemeController].
///
/// [dark] is the app's original (and only) look, lifted verbatim from
/// `main.dart` so switching the theme layer on changes nothing in dark mode.
/// [light] is the new counterpart: light surfaces with dark text, keeping the
/// lime brand accent. Widgets that must flip between the two should read
/// `Theme.of(context).colorScheme.*` rather than fixed [AppColors] constants.
final class AppTheme {
  /// Private constructor — this class is never instantiated.
  AppTheme._();

  /// The original dark appearance. Copied byte-for-byte from the former inline
  /// theme in `main.dart`; do not "improve" it — dark mode must stay identical
  /// to the shipped build.
  static ThemeData get dark => ThemeData(
    primarySwatch: CustomTheme.kToDark,
    primaryColor: AppColors.allPrimaryColor,
    useMaterial3: false,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.c000000,
      elevation: 0,
      foregroundColor: AppColors.cFFFFFF,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.allPrimaryColor,
    ),
    scaffoldBackgroundColor: AppColors.scaffoldColor,
  );

  /// The light appearance: white surfaces, dark text/icons, lime accent.
  ///
  /// Mirrors [dark]'s structure with light-side values and a proper light
  /// [ColorScheme] so migrated widgets reading `colorScheme.*` render
  /// correctly. Per-widget hardcoded-colour cleanup lands separately.
  static ThemeData get light => ThemeData(
    primarySwatch: CustomTheme.kToDark,
    primaryColor: AppColors.allPrimaryColor,
    useMaterial3: false,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cFFFFFF,
      elevation: 0,
      foregroundColor: AppColors.c000000,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.allPrimaryColor,
    ),
    scaffoldBackgroundColor: AppColors.cFFFFFF,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.allPrimaryColor,
      brightness: Brightness.light,
    ),
  );
}
