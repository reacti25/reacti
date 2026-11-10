// The Permissions screen (Settings → Permissions) must open cleanly: its
// first load once handed setState a Future, which Flutter rejects.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/permission/presentation/permission_list_screen.dart';

void main() {
  testWidgets('opens without a setState error', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (context, _) => const MaterialApp(home: PermissionListScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PermissionListScreen), findsOneWidget);
  });
}
