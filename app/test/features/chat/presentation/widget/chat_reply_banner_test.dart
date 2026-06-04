// Widget tests for ChatReplyBanner — the "Replying to …" banner shown
// above the message composer, extracted from InboxScreen and
// GroupInboxScreen which carried byte-identical inline copies.

import 'package:reacti_app/features/chat/presentation/widget/chat_reply_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('ChatReplyBanner', () {
    testWidgets('renders the "Replying to" header with the chat name', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        ChatReplyBanner(chatName: 'Alice', onClose: () {}),
      );

      expect(find.text('Replying to: Alice'), findsOneWidget);
    });

    testWidgets('renders the quoted text when replying to a text message', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        ChatReplyBanner(
          chatName: 'Alice',
          replyMessage: 'the original message',
          onClose: () {},
        ),
      );

      expect(find.text('the original message'), findsOneWidget);
    });

    testWidgets('labels the media kind when replying to media', (tester) async {
      await pumpInApp(
        tester,
        ChatReplyBanner(
          chatName: 'Alice',
          replyImage: 'https://example.com/clip.mp4',
          replyMediaType: 'video',
          onClose: () {},
        ),
      );

      expect(find.text('Replying to video'), findsOneWidget);
    });

    testWidgets('falls back to "image" when no media type is given', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        ChatReplyBanner(
          chatName: 'Alice',
          replyImage: 'https://example.com/photo.jpg',
          onClose: () {},
        ),
      );

      expect(find.text('Replying to image'), findsOneWidget);
    });

    testWidgets('tapping the close button invokes onClose', (tester) async {
      var closed = false;

      await pumpInApp(
        tester,
        ChatReplyBanner(
          chatName: 'Alice',
          replyMessage: 'hi',
          onClose: () => closed = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });
  });
}
