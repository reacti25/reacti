// Widget tests for ChatAppBarTitle — the avatar + name app-bar title
// shared by InboxScreen and GroupInboxScreen.
//
// An empty avatar URL is used so no network image is fetched; the test
// only exercises the name rendering.

import 'package:flutter/material.dart';
import 'package:reacti_app/common_widget/group_avatar.dart';
import 'package:reacti_app/features/chat/presentation/widget/chat_app_bar_title.dart';
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

    testWidgets('a group with no image shows the people-icon fallback', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const ChatAppBarTitle(name: 'Team', imageUrl: '', isGroup: true),
      );

      // Matches the chat list — never a blank circle for a group.
      expect(find.byType(GroupAvatar), findsOneWidget);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });

    testWidgets('a 1:1 chat does not use the group avatar', (tester) async {
      await pumpInApp(
        tester,
        const ChatAppBarTitle(name: 'Jane', imageUrl: '', isGroup: false),
      );

      expect(find.byType(GroupAvatar), findsNothing);
    });

    testWidgets('tapping the avatar invokes onAvatarTap', (tester) async {
      var taps = 0;
      await pumpInApp(
        tester,
        ChatAppBarTitle(name: 'Jane', imageUrl: '', onAvatarTap: () => taps++),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('no GestureDetector when onAvatarTap is null', (tester) async {
      await pumpInApp(
        tester,
        const ChatAppBarTitle(name: 'Jane', imageUrl: ''),
      );

      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}
