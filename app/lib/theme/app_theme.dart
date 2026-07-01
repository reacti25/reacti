import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's two [ThemeData] objects, selected at runtime by `ThemeController`.
///
/// [dark] reproduces the app's original look; every dark token equals the
/// colour widgets used before the light-theme migration, so dark mode is
/// unchanged. [light] is the cohesive light counterpart. Both are built from a
/// single [_Palette] so the component themes (app bar, card, inputs, switch,
/// chip, dialog, bottom sheet, text) stay in lock-step — widgets should read
/// `Theme.of(context).colorScheme.*` / `textTheme.*` rather than fixed
/// [AppColors] so they flip correctly.
final class AppTheme {
  /// Private constructor — this class is never instantiated.
  AppTheme._();

  /// Dark palette — the values the app hardcoded before the migration.
  static const _Palette _darkPalette = _Palette(
    brightness: Brightness.dark,
    scaffold: Color(0xFF010101), // AppColors.scaffoldColor
    surface: Color(0xFF18181B), // AppColors.c18181B — cards / rows
    surfaceHigh: Color(0xFF242424), // AppColors.c242424 — sheets / menus
    appBar: Color(0xFF000000), // AppColors.c000000
    navBar: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF), // primary text/icons were Colors.white
    onSurfaceVariant: Color(0xFFCCCCCC), // AppColors.cCCCCCC — secondary text
    outline: Color(0xFF333333), // AppColors.c333333 — borders/dividers
    fieldFill: Color(0xFF000000), // AppColors.c000000 — input background
  );

  /// Light palette — the new, cohesive light-mode values.
  static const _Palette _lightPalette = _Palette(
    brightness: Brightness.light,
    scaffold: Color(0xFFFFFFFF),
    surface: Color(0xFFF3F3F4), // cards / rows — off-white to read on scaffold
    surfaceHigh: Color(0xFFFFFFFF), // sheets / menus
    appBar: Color(0xFFFFFFFF),
    navBar: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1A1A), // primary text/icons
    onSurfaceVariant: Color(0xFF5B5B60), // secondary text — AA on white
    outline: Color(0xFFE2E2E5), // borders/dividers
    fieldFill: Color(0xFFF3F3F4), // input background
  );

  /// The original dark appearance. Do not "improve" it — dark mode must stay
  /// identical to the shipped build.
  static ThemeData get dark => _build(_darkPalette);

  /// The cohesive light appearance.
  static ThemeData get light => _build(_lightPalette);

  /// Assembles a [ThemeData] from [p], wiring the colour scheme and every
  /// component theme so Material widgets are themed for free and custom widgets
  /// can read tokens off the theme.
  static ThemeData _build(_Palette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: AppColors.allPrimaryColor,
      onPrimary: const Color(0xFF1A1A1A), // dark text/icons on the lime accent
      secondary: AppColors.allPrimaryColor,
      onSecondary: const Color(0xFF1A1A1A),
      error: const Color(0xFFD12E34),
      onError: const Color(0xFFFFFFFF),
      surface: p.surface,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceVariant,
      outline: p.outline,
    );

    final baseText = (p.brightness == Brightness.dark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(bodyColor: p.onSurface, displayColor: p.onSurface);

    return ThemeData(
      useMaterial3: false,
      brightness: p.brightness,
      primaryColor: AppColors.allPrimaryColor,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.scaffold,
      canvasColor: p.scaffold,
      dividerColor: p.outline,
      textTheme: baseText,
      iconTheme: IconThemeData(color: p.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBar,
        foregroundColor: p.onSurface,
        elevation: 0,
        systemOverlayStyle:
            p.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
      ),
      cardColor: p.surface,
      cardTheme: CardThemeData(color: p.surface, elevation: 0),
      bottomAppBarTheme: BottomAppBarThemeData(color: p.navBar),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surfaceHigh),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceHigh,
        titleTextStyle: baseText.titleMedium,
        contentTextStyle: baseText.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceHigh,
        textStyle: baseText.bodyMedium,
      ),
      dividerTheme: DividerThemeData(color: p.outline),
      listTileTheme: ListTileThemeData(
        iconColor: p.onSurface,
        textColor: p.onSurface,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.allPrimaryColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fieldFill,
        hintStyle: TextStyle(color: p.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.allPrimaryColor),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.allPrimaryColor
                  : p.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.allPrimaryColor.withValues(alpha: 0.45)
                  : p.outline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: AppColors.allPrimaryColor,
        labelStyle: TextStyle(color: p.onSurface),
        secondaryLabelStyle: const TextStyle(color: Color(0xFF1A1A1A)),
        side: BorderSide(color: p.outline),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors(
          onSurface: p.onSurface,
          onSurfaceVariant: p.onSurfaceVariant,
          surface: p.surface,
          surfaceHigh: p.surfaceHigh,
          fieldFill: p.fieldFill,
        ),
      ],
    );
  }
}

/// The colour inputs that distinguish the two themes.
///
/// One record fed into [AppTheme._build] so dark and light differ only by
/// these values, never by structure.
@immutable
class _Palette {
  const _Palette({
    required this.brightness,
    required this.scaffold,
    required this.surface,
    required this.surfaceHigh,
    required this.appBar,
    required this.navBar,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.fieldFill,
  });

  final Brightness brightness;
  final Color scaffold;
  final Color surface;
  final Color surfaceHigh;
  final Color appBar;
  final Color navBar;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color fieldFill;
}

/// Theme-flipping colours read via `context.appColors`, for the roles that
/// [ColorScheme] does not cleanly name (a higher surface for sheets/menus, and
/// the input fill). Mirrors the active theme's [_Palette]; dark values equal
/// the pre-migration hardcodes so dark mode is unchanged.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// Creates the semantic colour set.
  const AppSemanticColors({
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surface,
    required this.surfaceHigh,
    required this.fieldFill,
  });

  /// Primary content colour on the scaffold / app-bar surface.
  final Color onSurface;

  /// Secondary/muted content colour (section headers, timestamps, captions).
  final Color onSurfaceVariant;

  /// Card / row surface colour.
  final Color surface;

  /// Elevated surface for sheets and popup menus.
  final Color surfaceHigh;

  /// Fill for inset controls (text fields).
  final Color fieldFill;

  @override
  AppSemanticColors copyWith({
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? surface,
    Color? surfaceHigh,
    Color? fieldFill,
  }) => AppSemanticColors(
    onSurface: onSurface ?? this.onSurface,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    fieldFill: fieldFill ?? this.fieldFill,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant:
          Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      fieldFill: Color.lerp(fieldFill, other.fieldFill, t)!,
    );
  }
}

/// Ergonomic access to [AppSemanticColors] from a [BuildContext].
extension AppSemanticColorsX on BuildContext {
  /// The active theme's [AppSemanticColors], falling back to dark values (the
  /// original hardcodes) when a theme without the extension is in scope — e.g.
  /// a bare `MaterialApp` in a widget test — so nothing throws.
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      const AppSemanticColors(
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFCCCCCC),
        surface: Color(0xFF18181B),
        surfaceHigh: Color(0xFF242424),
        fieldFill: Color(0xFF000000),
      );
}
