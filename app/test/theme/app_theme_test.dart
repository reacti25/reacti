// Unit tests for the theme hub. Dark keeps the pre-migration values so dark
// mode stays pixel-identical; light is a real light theme; the ColorScheme is
// derived from the ReactiColors tokens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark keeps the original canvas + white content', () {
      final dark = AppTheme.dark;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF010101));
      expect(dark.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(dark.extension<ReactiColors>()?.canvas, const Color(0xFF010101));
    });

    test('light uses a warm deeper canvas with white cards', () {
      final light = AppTheme.light;
      expect(light.brightness, Brightness.light);
      // Canvas is a warm, slightly-deeper neutral (not near-white); the tonal
      // step to the white cards is what creates depth.
      expect(light.scaffoldBackgroundColor, const Color(0xFFE6E3DC));
      expect(light.extension<ReactiColors>()?.card, const Color(0xFFFFFFFF));
      expect(light.colorScheme.onSurface, const Color(0xFF161513));
    });

    test('light cards carry a tinted (non-black) shadow; dark stays flat', () {
      expect(AppTheme.light.extension<ReactiColors>()?.cardShadow, isNotEmpty);
      expect(AppTheme.dark.extension<ReactiColors>()?.cardShadow, isEmpty);
    });

    test(
      'light ColorScheme.primary is the darkened brand accent, not lime',
      () {
        final light = AppTheme.light;
        // Material-drawn text/icons default to the legible accent, not lime.
        expect(light.colorScheme.primary, const Color(0xFF4F5E00));
        // The lime block lives in primaryContainer.
        expect(light.colorScheme.primaryContainer, const Color(0xFFDCFC53));
      },
    );

    test('both themes register the ReactiColors extension', () {
      expect(AppTheme.dark.extension<ReactiColors>(), isNotNull);
      expect(AppTheme.light.extension<ReactiColors>(), isNotNull);
    });

    test('ReactiColors lerp interpolates a token', () {
      final mid = ReactiColors.dark.lerp(ReactiColors.light, 0.5);
      expect(
        mid.canvas,
        Color.lerp(ReactiColors.dark.canvas, ReactiColors.light.canvas, 0.5),
      );
    });
  });
}
