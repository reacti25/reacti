// Shared widget-test harness.
//
// `flutter test` runs widgets outside a real app, so several inherited
// widgets the chat bubbles depend on are missing by default:
//
//   * `ScreenUtilInit` — makes the `.h`/`.w`/`.r`/`.sp` sizing extensions
//     resolve. Without it any widget using `flutter_screenutil` throws.
//   * `MaterialApp` — supplies `Directionality`, `MediaQuery`, theme and a
//     `Navigator`, all of which `Material`-family widgets assume.
//   * `Scaffold` + `SingleChildScrollView` — give the widget a bounded,
//     scrollable layout so tall bubbles do not overflow the test viewport.
//
// `pumpInApp` bundles all of that into one call so every widget test pumps
// the same minimal, deterministic shell. It is the generalised form of the
// `_wrap()` helper in
// `test/features/chat/widget/receiver_message_widget_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside the minimum app shell a chat widget needs under
/// `flutter test`, then settles a single frame.
///
/// The shell is, from outside in:
///
///   * [ScreenUtilInit] with a `375x812` design size and `minTextAdapt`
///     enabled, so the `.h`/`.w`/`.r`/`.sp` extensions resolve exactly as
///     they do on a real device.
///   * [MaterialApp] whose `home` is a [Scaffold] — this provides
///     [Directionality], [MediaQuery], the [Theme] and a [Navigator].
///   * A [SingleChildScrollView] wrapping [child] so a bubble taller than
///     the test viewport lays out without a render overflow.
///
/// After mounting it awaits a single [WidgetTester.pump] so the first frame
/// is committed. It deliberately does **not** call `pumpAndSettle`: chat
/// bubbles can host indefinitely-running animations (spinners, video
/// players) that would make `pumpAndSettle` time out.
///
/// Usage:
///
/// ```dart
/// await pumpInApp(tester, const SenderTextBubble(message: 'hi'));
/// expect(find.text('hi'), findsOneWidget);
/// ```
///
/// [tester] is the active [WidgetTester]; [child] is the widget under test.
Future<void> pumpInApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder:
          (context, _) => MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
    ),
  );
  await tester.pump();
}
