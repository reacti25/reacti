// The walkthrough's opening card.
//
// Coach marks can teach where a button is. They cannot teach what the app
// does, because that needs a sealed message and a reaction, and a brand-new
// account has neither. This card is the only place the mechanic is spelled
// out inside the app for a logged-in user, so what is pinned here is that all
// four steps actually render and that the card can be got rid of.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/tour/tour_recap_sheet.dart';

/// Pumps a screen whose only job is a button that opens the sheet.
///
/// The surface is sized to the design's 375x812 logical phone. The default
/// 800x600 test window is shorter than any handset the app runs on, and the
/// sheet would scroll there for reasons no real user ever hits.
Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1125, 2436);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder:
          (_, _) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed: () => showTourRecapSheet(context),
                      child: const Text('open'),
                    ),
              ),
            ),
          ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('spells out all three steps of a Reacti', (tester) async {
    await _open(tester);

    expect(find.text('How a Reacti works'), findsOneWidget);
    // Send -> they reveal -> the reaction comes back. Drop any one of these and
    // the walkthrough stops explaining the product.
    expect(find.textContaining('Send a photo or video'), findsOneWidget);
    expect(find.textContaining('tap to reveal'), findsOneWidget);
    expect(find.textContaining('sends it back to you'), findsOneWidget);
  });

  testWidgets('numbers the steps 1 to 3', (tester) async {
    await _open(tester);

    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('4'), findsNothing);
  });

  testWidgets('the button dismisses it so the mark can start', (tester) async {
    await _open(tester);

    // FirstRunTour.start awaits this sheet before firing the coach mark. A
    // card that cannot be closed would strand the whole walkthrough behind it.
    await tester.tap(find.text('Send my first Reacti'));
    await tester.pumpAndSettle();

    expect(find.text('How a Reacti works'), findsNothing);
  });
}
