// Widget tests for SenderReplyQuote — the quoted-reply preview shown
// above a sent chat bubble, extracted from SenderMessageWidget.
//
// SenderReplyQuote deliberately takes a loosely-typed (`dynamic`) reply
// object so it tolerates API variation, so these tests feed it a small
// duck-typed fake rather than the full ReplyTo model (which has its own
// tests in reply_to_test.dart). No `file` is set, so no network image
// is loaded.

import 'package:reacti_app/features/chat/presentation/widget/sender_reply_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

/// Minimal stand-in for the quoted message's sender.
class FakeSender {
  final String? firstName;
  FakeSender(this.firstName);
}

/// Minimal duck-typed stand-in for a quoted reply, exposing exactly the
/// fields SenderReplyQuote reads.
class FakeReply {
  final int? id;
  final String? text;
  final String? file;
  final dynamic isBlurred;
  final String? mediaType;
  final FakeSender? sender;

  FakeReply({
    this.id,
    this.text,
    this.file,
    this.isBlurred,
    this.mediaType,
    this.sender,
  });
}

void main() {
  group('SenderReplyQuote', () {
    testWidgets('renders nothing when replyTo is null', (tester) async {
      await pumpInApp(tester, const SenderReplyQuote(replyTo: null));

      // A null reply collapses to SizedBox.shrink — no tappable preview.
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('renders the quoted sender name and text', (tester) async {
      await pumpInApp(
        tester,
        SenderReplyQuote(
          replyTo: FakeReply(
            id: 5,
            text: 'the original message',
            sender: FakeSender('Bob'),
          ),
        ),
      );

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('the original message'), findsOneWidget);
    });

    testWidgets('tapping the preview invokes onTapReply with the reply id', (
      tester,
    ) async {
      int? tappedId;

      await pumpInApp(
        tester,
        SenderReplyQuote(
          replyTo: FakeReply(
            id: 42,
            text: 'jump to me',
            sender: FakeSender('Ann'),
          ),
          onTapReply: (id) => tappedId = id,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tappedId, 42);
    });
  });
}
