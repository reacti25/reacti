import 'package:reacti_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's semantic colour system and the two [ThemeData] it produces.
///
/// One source of truth for colour. [ReactiColors] holds every semantic role
/// (canvas vs card, brand fill vs brand accent, chat bubbles, text tiers,
/// hairline, avatar placeholder) with a light and a dark value; the Material
/// [ColorScheme] + component themes are derived from the same values so most
/// widgets are correct with no per-widget work.
///
/// **Dark is unchanged** — every dark token equals the colour the app hardcoded
/// before the migration, so dark mode is pixel-identical. Only the light values
/// are new. Widgets must read `Theme.of(context)` / `context.reacti` rather than
/// fixed [AppColors] wherever a colour has to flip between modes.
final class AppTheme {
  AppTheme._();

  /// The light appearance: off-white canvas, white cards, darkened-lime accent.
  static ThemeData get light => _build(ReactiColors.light);

  /// The original dark appearance. Do not "improve" it.
  static ThemeData get dark => _build(ReactiColors.dark);

  /// Assembles a [ThemeData] from a [ReactiColors] token set.
  static ThemeData _build(ReactiColors c) {
    final isDark = c.brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: c.brightness,
      // Material-drawn accents/text default to the legible brand accent
      // (darkened lime on light, lime on dark), never lime-on-white.
      primary: c.brandAccent,
      onPrimary: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
      // The lime block, for filled buttons / selected states.
      primaryContainer: c.brandFill,
      onPrimaryContainer: c.onBrandFill,
      secondary: c.brandAccent,
      onSecondary: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
      surface: c.card,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerHighest: c.surfaceVariant,
      outline: c.outline,
      outlineVariant: c.hairline,
      error: c.error,
      onError: const Color(0xFFFFFFFF),
    );

    final baseText = (isDark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(bodyColor: c.textPrimary, displayColor: c.textPrimary);

    return ThemeData(
      useMaterial3: false,
      brightness: c.brightness,
      primaryColor: c.brandFill,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.hairline,
      shadowColor: c.shadow,
      textTheme: baseText,
      iconTheme: IconThemeData(color: c.iconPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.iconPrimary,
        elevation: 0,
        // A soft hairline detaches the bar from the canvas in light; dark keeps
        // its borderless look.
        shape: isDark ? null : Border(bottom: BorderSide(color: c.hairline)),
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardColor: c.card,
      // A soft tinted shadow lifts Material cards off the canvas in light; dark
      // has a transparent shadow, so it stays flat and unchanged.
      cardTheme: CardThemeData(
        color: c.card,
        elevation: isDark ? 0 : 2,
        shadowColor: c.shadow,
        surfaceTintColor: Colors.transparent,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: c.card,
        elevation: isDark ? 0 : 8,
        shadowColor: c.shadow,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        elevation: isDark ? 0 : 8,
        shadowColor: c.shadow,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        elevation: isDark ? 24 : 8,
        shadowColor: c.shadow,
        titleTextStyle: baseText.titleMedium,
        contentTextStyle: baseText.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        textStyle: baseText.bodyMedium,
      ),
      dividerTheme: DividerThemeData(color: c.hairline, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.iconPrimary,
        textColor: c.textPrimary,
        subtitleTextStyle: baseText.bodyMedium?.copyWith(
          color: c.textSecondary,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.brandAccent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariant,
        hintStyle: TextStyle(color: c.textTertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.brandAccent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected)
                  ? c.onBrandFill
                  : const Color(0xFFFFFFFF),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? c.brandFill : c.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        selectedColor: c.brandFill,
        labelStyle: TextStyle(color: c.textPrimary),
        secondaryLabelStyle: TextStyle(color: c.onBrandFill),
        side: BorderSide(color: c.hairline),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brandFill,
          foregroundColor: c.onBrandFill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.brandAccent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brandAccent),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}

/// The semantic colour tokens, resolved per theme and read via
/// `context.reacti`. Holds the roles Material's [ColorScheme] cannot express
/// (brand fill vs accent, chat bubbles, canvas vs card, hairline, avatar
/// placeholder, text tiers).
@immutable
class ReactiColors extends ThemeExtension<ReactiColors> {
  const ReactiColors({
    required this.brightness,
    required this.canvas,
    required this.card,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
    required this.iconPrimary,
    required this.brandFill,
    required this.onBrandFill,
    required this.brandAccent,
    required this.bubbleIn,
    required this.onBubbleIn,
    required this.bubbleOut,
    required this.onBubbleOut,
    required this.chatBackground,
    required this.avatarPlaceholderBg,
    required this.avatarPlaceholderGlyph,
    required this.error,
    required this.outline,
    required this.shadow,
  });

  /// Which mode these tokens belong to (drives a few Material defaults).
  final Brightness brightness;

  /// Scaffold background — a soft off-white in light, near-black in dark.
  final Color canvas;

  /// Rows, cards, app bar, nav bar and sheets — sit on [canvas].
  final Color card;

  /// Subtle fill for inputs, unselected chips/segments and disabled controls.
  final Color surfaceVariant;

  /// Titles, names, body copy.
  final Color textPrimary;

  /// Subtitles, timestamps, muted copy.
  final Color textSecondary;

  /// Hints and placeholders.
  final Color textTertiary;

  /// 1px dividers and borders.
  final Color hairline;

  /// Default icon colour (back, gear, kebab).
  final Color iconPrimary;

  /// Lime block for buttons / selected pills / switch-on track.
  final Color brandFill;

  /// Text/icon colour drawn on top of [brandFill].
  final Color onBrandFill;

  /// Brand colour for text/icons/active states — darkened lime on light so it
  /// stays legible on white; lime on dark.
  final Color brandAccent;

  /// Incoming chat bubble surface and its text colour.
  final Color bubbleIn;
  final Color onBubbleIn;

  /// Outgoing chat bubble surface and its text colour.
  final Color bubbleOut;
  final Color onBubbleOut;

  /// The conversation background (never pure white in light).
  final Color chatBackground;

  /// Avatar placeholder fill and glyph, so blank avatars don't vanish on white.
  final Color avatarPlaceholderBg;
  final Color avatarPlaceholderGlyph;

  /// Error / denied red.
  final Color error;

  /// Stronger border for emphasised outlines.
  final Color outline;

  /// Tinted card/sheet shadow colour (transparent in dark, which has none).
  final Color shadow;

  /// The soft, tinted elevation applied to cards, rows and sheets — empty in
  /// dark (transparent [shadow]) so dark mode keeps its flat, shadowless look.
  List<BoxShadow> get cardShadow =>
      shadow.a == 0
          ? const <BoxShadow>[]
          : [
            BoxShadow(
              color: shadow,
              offset: const Offset(0, 2),
              blurRadius: 12,
            ),
          ];

  /// Light tokens — a warm 3-step neutral ramp with a tinted card shadow, so
  /// cards lift off a slightly-deeper canvas (see the refinement plan's §2).
  static const ReactiColors light = ReactiColors(
    brightness: Brightness.light,
    // A step deeper/warmer than a flat off-white so the white cards clearly
    // float — the main canvas↔card separation lever (tunable).
    canvas: Color(0xFFE6E3DC),
    card: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1EFEA), // "sunken" — recessed vs the white card
    textPrimary: Color(0xFF161513), // near-black, slight warmth
    textSecondary: Color(0xFF5F5D57), // a true mid-grey, not pale
    textTertiary: Color(0xFF8B897F),
    hairline: Color(0xFFDEDCD6), // a touch stronger
    iconPrimary: Color(0xFF1A1A1A),
    brandFill: Color(0xFFDCFC53),
    onBrandFill: Color(0xFF1A1A1A),
    brandAccent: Color(0xFF4F5E00),
    bubbleIn: Color(0xFFFFFFFF),
    onBubbleIn: Color(0xFF161513),
    bubbleOut: Color(0xFFE7F59C),
    onBubbleOut: Color(0xFF1A1A1A),
    chatBackground: Color(0xFFE6E3DC),
    avatarPlaceholderBg: Color(0xFFF1EFEA),
    avatarPlaceholderGlyph: Color(0xFF8B897F),
    error: Color(0xFFD64B3F),
    outline: Color(0xFFC6C8CC),
    // Warm, tinted (not black) shadow of the background colour.
    shadow: Color(0x1A322E24),
  );

  /// Dark tokens — equal to today's hardcoded colours, so dark is unchanged.
  static const ReactiColors dark = ReactiColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF010101), // AppColors.scaffoldColor
    card: Color(0xFF18181B), // AppColors.c18181B
    surfaceVariant: Color(0xFF252529), // AppColors.c252529
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF), // white @ 70%
    textTertiary: Color(0x66FFFFFF), // white @ 40%
    hairline: Color(0xFF2A2A2E),
    iconPrimary: Color(0xFFFFFFFF),
    brandFill: Color(0xFFDCFC53),
    onBrandFill: Color(0xFF1A1A1A),
    brandAccent: Color(0xFFDCFC53),
    bubbleIn: Color(0xFF1A1E0A), // receiver_text_bubble today
    onBubbleIn: Color(0xFFFFFFFF),
    bubbleOut: Color(0xFFDCFC53), // sender bubble is lime today
    onBubbleOut: Color(0xFF000000),
    chatBackground: Color(0xFF010101),
    avatarPlaceholderBg: Color(0xFF333333),
    avatarPlaceholderGlyph: Color(0xFF8A8A8A),
    error: Color(0xFFD12E34),
    outline: Color(0xFF333333),
    shadow: Color(0x00000000), // dark has no card shadows today — keep flat
  );

  @override
  ReactiColors copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? card,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? hairline,
    Color? iconPrimary,
    Color? brandFill,
    Color? onBrandFill,
    Color? brandAccent,
    Color? bubbleIn,
    Color? onBubbleIn,
    Color? bubbleOut,
    Color? onBubbleOut,
    Color? chatBackground,
    Color? avatarPlaceholderBg,
    Color? avatarPlaceholderGlyph,
    Color? error,
    Color? outline,
    Color? shadow,
  }) {
    return ReactiColors(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      hairline: hairline ?? this.hairline,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      brandFill: brandFill ?? this.brandFill,
      onBrandFill: onBrandFill ?? this.onBrandFill,
      brandAccent: brandAccent ?? this.brandAccent,
      bubbleIn: bubbleIn ?? this.bubbleIn,
      onBubbleIn: onBubbleIn ?? this.onBubbleIn,
      bubbleOut: bubbleOut ?? this.bubbleOut,
      onBubbleOut: onBubbleOut ?? this.onBubbleOut,
      chatBackground: chatBackground ?? this.chatBackground,
      avatarPlaceholderBg: avatarPlaceholderBg ?? this.avatarPlaceholderBg,
      avatarPlaceholderGlyph:
          avatarPlaceholderGlyph ?? this.avatarPlaceholderGlyph,
      error: error ?? this.error,
      outline: outline ?? this.outline,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ReactiColors lerp(ThemeExtension<ReactiColors>? other, double t) {
    if (other is! ReactiColors) return this;
    return ReactiColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      brandFill: Color.lerp(brandFill, other.brandFill, t)!,
      onBrandFill: Color.lerp(onBrandFill, other.onBrandFill, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      bubbleIn: Color.lerp(bubbleIn, other.bubbleIn, t)!,
      onBubbleIn: Color.lerp(onBubbleIn, other.onBubbleIn, t)!,
      bubbleOut: Color.lerp(bubbleOut, other.bubbleOut, t)!,
      onBubbleOut: Color.lerp(onBubbleOut, other.onBubbleOut, t)!,
      chatBackground: Color.lerp(chatBackground, other.chatBackground, t)!,
      avatarPlaceholderBg:
          Color.lerp(avatarPlaceholderBg, other.avatarPlaceholderBg, t)!,
      avatarPlaceholderGlyph:
          Color.lerp(avatarPlaceholderGlyph, other.avatarPlaceholderGlyph, t)!,
      error: Color.lerp(error, other.error, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Ergonomic access to [ReactiColors] from a [BuildContext].
extension ReactiColorsX on BuildContext {
  /// The active theme's [ReactiColors], falling back to the dark tokens (the
  /// original hardcodes) when a theme without the extension is in scope — e.g.
  /// a bare `MaterialApp` in a widget test — so nothing throws.
  ReactiColors get reacti =>
      Theme.of(this).extension<ReactiColors>() ?? ReactiColors.dark;
}
