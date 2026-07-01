// Unit tests for AppSemanticColors — the theme-flipping content colour used by
// the hardcoded-colour migration. Dark must equal the old hardcoded white so
// dark mode stays pixel-identical.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/theme/app_theme.dart';

void main() {
  group('AppSemanticColors', () {
    test('dark onSurface is pure white (unchanged from the old hardcode)', () {
      expect(AppSemanticColors.dark.onSurface, const Color(0xFFFFFFFF));
    });

    test('light onSurface is near-black (flipped)', () {
      expect(AppSemanticColors.light.onSurface, const Color(0xFF1A1A1A));
    });

    test('both themes register the extension', () {
      expect(
        AppTheme.dark.extension<AppSemanticColors>()?.onSurface,
        const Color(0xFFFFFFFF),
      );
      expect(
        AppTheme.light.extension<AppSemanticColors>()?.onSurface,
        const Color(0xFF1A1A1A),
      );
    });

    test('lerp interpolates onSurface', () {
      final mid = AppSemanticColors.dark.lerp(AppSemanticColors.light, 0.5);
      expect(
        mid.onSurface,
        Color.lerp(
          AppSemanticColors.dark.onSurface,
          AppSemanticColors.light.onSurface,
          0.5,
        ),
      );
    });
  });
}
