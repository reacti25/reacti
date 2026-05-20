import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';

/// Namespace exposing the app's brand [MaterialColor] swatch and [ThemeData].
///
/// Centralises theme construction so widgets reference one canonical theme.
final class CustomTheme {
  /// Private constructor — this class is never instantiated.
  CustomTheme._();

  /// The brand swatch; every shade resolves to the same brand colour
  /// (`0xFFDCFC53`) so shade selection never changes the rendered colour.
  static const MaterialColor kToDark = MaterialColor(
    0xFFDCFC53, // 0% comes in here, this will be color picked if no shade is selected when defining a Color property which doesn’t require a swatch.
    <int, Color>{
      50: Color(0xFFDCFC53), //10%
      100: Color(0xFFDCFC53), //20%
      200: Color(0xFFDCFC53), //30%
      300: Color(0xFFDCFC53), //40%
      400: Color(0xFFDCFC53), //50%
      500: Color(0xFFDCFC53), //60%
      600: Color(0xFFDCFC53), //70%
      700: Color(0xFFDCFC53), //80%
      800: Color(0xFFDCFC53), //90%
      900: Color(0xFFDCFC53), //100%
    },
  );

  /// The application's primary [ThemeData], built around [kToDark] and a
  /// white scaffold/primary colour with Material 3 enabled.
  static ThemeData get mainTheme {
    return ThemeData(
      primaryColor: AppColors.cFFFFFF,
      primarySwatch: CustomTheme.kToDark,
      scaffoldBackgroundColor: AppColors.cFFFFFF,
      useMaterial3: true,
    );
  }
}
