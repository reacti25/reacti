// Widget test for the ForwardedLabel indicator.

import 'package:reacti_app/features/chat/presentation/widget/forwarded_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  testWidgets('ForwardedLabel renders the label and icon', (tester) async {
    await pumpInApp(tester, const ForwardedLabel(color: Colors.grey));

    expect(find.text('Forwarded'), findsOneWidget);
    expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
  });
}
