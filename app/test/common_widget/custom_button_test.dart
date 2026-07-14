// Unit tests for CustomButton — specifically that a null onTap renders the
// disabled (greyed) state, which SearchScreen relies on to block double-sends
// of a friend request while one is in flight.

import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/widget_harness.dart';

void main() {
  testWidgets('null onTap renders a disabled button', (tester) async {
    await pumpInApp(tester, const CustomButton(onTap: null, btnName: 'Send'));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.enabled, isFalse);
  });

  testWidgets('non-null onTap is enabled and fires on tap', (tester) async {
    var taps = 0;
    await pumpInApp(
      tester,
      CustomButton(onTap: () => taps++, btnName: 'Send'),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.enabled, isTrue);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(taps, 1);
  });
}
