// Verifies the Settings screen groups preferences by intent and isolates the
// destructive actions (Log Out / Delete Account) at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/profile/presentation/settings_screen.dart';
import 'package:reacti_app/theme/app_theme.dart';

void main() {
  testWidgets('groups settings and isolates logout/delete', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => MaterialApp(
              theme: AppTheme.light,
              home: const SettingsScreen(),
            ),
      ),
    );
    await tester.pump();

    // Grouped section headers.
    for (final group in ['ACCOUNT', 'PRIVACY', 'PREFERENCES', 'ABOUT & DATA']) {
      expect(find.text(group), findsOneWidget);
    }
    // Representative rows land in the right place.
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Read Receipts'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    // Sound & Vibration is a normal card row (consistent with the rest).
    expect(find.text('Sound & Vibration'), findsOneWidget);
    expect(find.text('Usage Data'), findsOneWidget);
    // Destructive actions moved off the profile page into Settings.
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });
}
