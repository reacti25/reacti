// Widget test for InboxBlockedNotice — the static "you have been blocked"
// notice shown in InboxScreen in place of the composer.

import 'package:achiar_expert_app/features/chat/presentation/widget/inbox_blocked_notice.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('InboxBlockedNotice', () {
    testWidgets('renders the blocked explanation text', (tester) async {
      await pumpInApp(tester, const InboxBlockedNotice());

      expect(
        find.text(
          'You can not send any message to this user. '
          'You have been blocked.',
        ),
        findsOneWidget,
      );
    });
  });
}
