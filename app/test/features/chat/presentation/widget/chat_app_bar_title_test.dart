// Widget tests for ChatAppBarTitle — the avatar + name app-bar title
// shared by InboxScreen and GroupInboxScreen.
//
// An empty avatar URL is used so no network image is fetched; the test
// only exercises the name rendering.

import 'package:achiar_expert_app/features/chat/presentation/widget/chat_app_bar_title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('ChatAppBarTitle', () {
    testWidgets('renders the conversation name', (tester) async {
      await pumpInApp(
        tester,
        const ChatAppBarTitle(name: 'Team Reacti', imageUrl: ''),
      );

      expect(find.text('Team Reacti'), findsOneWidget);
    });
  });
}
