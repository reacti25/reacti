// Widget test for Task 1: the "Reacti" wordmark is legible on light.
//
// The lockup SVG bakes the lime wordmark into the badge, so on the off-white
// canvas the lettering nearly vanished. In light mode the login screen now
// renders a light-variant asset whose wordmark paths are the darkened brand
// (#4F5E00); in dark mode it renders the original asset, unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reacti_app/features/auth/presentation/login/login_screen.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/provider/auth_provider.dart';
import 'package:reacti_app/theme/app_theme.dart';

void main() {
  Future<String> pumpAndReadLogo(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(),
              child: MaterialApp(theme: theme, home: const LoginScreen()),
            ),
      ),
    );
    await tester.pump();
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
    return (svg.bytesLoader as SvgAssetLoader).assetName;
  }

  testWidgets('light: uses the darkened-wordmark logo variant', (tester) async {
    expect(
      await pumpAndReadLogo(tester, AppTheme.light),
      Assets.icons.appLogoLight,
    );
  });

  testWidgets('dark: uses the original logo (unchanged)', (tester) async {
    expect(await pumpAndReadLogo(tester, AppTheme.dark), Assets.icons.appLogo);
  });
}
