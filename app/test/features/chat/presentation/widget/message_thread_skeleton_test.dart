import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/presentation/widget/message_thread_skeleton.dart';
import 'package:shimmer/shimmer.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('renders shimmer skeleton bubbles while a thread loads', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const MessageThreadSkeleton()));
    await tester.pump();

    // Wrapped in a shimmer and shows the full set of placeholder bubbles.
    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(Container), findsNWidgets(8));
  });
}
