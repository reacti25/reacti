// Unit tests for the theme hub. Dark must keep the pre-migration values so
// dark mode stays pixel-identical; light must be a real light theme.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark keeps the original scaffold + white content colour', () {
      final dark = AppTheme.dark;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF010101));
      expect(dark.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(
        dark.extension<AppSemanticColors>()?.onSurface,
        const Color(0xFFFFFFFF),
      );
    });

    test('light is a real light theme with near-black content', () {
      final light = AppTheme.light;
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(light.colorScheme.onSurface, const Color(0xFF1A1A1A));
      expect(
        light.extension<AppSemanticColors>()?.onSurface,
        const Color(0xFF1A1A1A),
      );
    });

    test('both themes register the semantic extension', () {
      expect(AppTheme.dark.extension<AppSemanticColors>(), isNotNull);
      expect(AppTheme.light.extension<AppSemanticColors>(), isNotNull);
    });

    test('AppSemanticColors lerp interpolates its colours', () {
      const a = AppSemanticColors(
        onSurface: Color(0xFF000000),
        onSurfaceVariant: Color(0xFF000000),
        surface: Color(0xFF000000),
        surfaceHigh: Color(0xFF000000),
        fieldFill: Color(0xFF000000),
      );
      const b = AppSemanticColors(
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        surfaceHigh: Color(0xFFFFFFFF),
        fieldFill: Color(0xFFFFFFFF),
      );
      final mid = a.lerp(b, 0.5);
      expect(mid.onSurface, Color.lerp(a.onSurface, b.onSurface, 0.5));
    });
  });
}
