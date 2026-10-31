// Leaving the username search must not touch its disposed search field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/search/presentation/search_screen.dart';

import '../../../support/widget_harness.dart';

void main() {
  testWidgets('leaving the screen disposes cleanly', (tester) async {
    await pumpInApp(tester, const SizedBox(height: 600, child: SearchScreen()));
    await tester.pumpWidget(const SizedBox());

    // It cleared its field after disposing it: "A TextEditingController was
    // used after being disposed" (found by the testing lab, #542).
    expect(tester.takeException(), isNull);
  });
}
