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

  /// Semantic colours registered on both themes, read via `context.appColors`.
  static const _darkExtensions = <ThemeExtension<dynamic>>[
    AppSemanticColors.dark,
  ];
  static const _lightExtensions = <ThemeExtension<dynamic>>[
    AppSemanticColors.light,
  ];

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
    extensions: _darkExtensions,
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
    extensions: _lightExtensions,
  );
}

/// Theme-flipping colours for content drawn on the app's *themed* scaffold /
/// app-bar surface (not on fixed-colour cards, bubbles or video overlays).
///
/// [onSurface] is white in dark and near-black in light, so a widget can use
/// one token and render correctly in both themes; use `.withValues(alpha:)`
/// for the muted variants that were `Colors.whiteNN`. The dark value equals
/// the colour widgets hardcoded before the migration, so dark mode is
/// unchanged. Read via `context.appColors`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// Creates the semantic colour set.
  const AppSemanticColors({required this.onSurface});

  /// Primary content colour on the scaffold / app-bar surface.
  final Color onSurface;

  /// Dark-theme values — equal to the previously hardcoded `Colors.white`.
  static const AppSemanticColors dark = AppSemanticColors(
    onSurface: Color(0xFFFFFFFF),
  );

  /// Light-theme counterpart: near-black content on light surfaces.
  static const AppSemanticColors light = AppSemanticColors(
    onSurface: Color(0xFF1A1A1A),
  );

  @override
  AppSemanticColors copyWith({Color? onSurface}) =>
      AppSemanticColors(onSurface: onSurface ?? this.onSurface);

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    );
  }
}

/// Ergonomic access to [AppSemanticColors] from a [BuildContext].
extension AppSemanticColorsX on BuildContext {
  /// The active theme's [AppSemanticColors], falling back to [dark] (the
  /// original hardcoded values) if a theme without the extension is in scope —
  /// e.g. a bare `MaterialApp` in a widget test. So a missing extension renders
  /// exactly as before the migration instead of throwing.
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;
}
