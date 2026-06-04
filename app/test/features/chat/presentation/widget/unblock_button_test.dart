// Widget tests for UnblockButton — the "Unblock" call-to-action shown in
// InboxScreen when the current user has blocked the peer.

import 'package:reacti_app/features/chat/presentation/widget/unblock_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('UnblockButton', () {
    testWidgets('renders the "Unblock" label', (tester) async {
      await pumpInApp(tester, UnblockButton(onTap: () {}));

      expect(find.text('Unblock'), findsOneWidget);
    });

    testWidgets('invokes onTap when pressed', (tester) async {
      var tapped = false;

      await pumpInApp(tester, UnblockButton(onTap: () => tapped = true));

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });
  });
}
