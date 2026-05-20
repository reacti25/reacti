// Widget tests for ReceiverReplyQuote — the quoted-reply preview shown
// above a received chat bubble, extracted from ReceiverMessageWidget.
//
// ReceiverReplyQuote takes a loosely-typed (`dynamic`) reply object, so
// these tests feed it a small duck-typed fake. No `file` is set, so no
// network image is loaded.

import 'package:reacti_app/features/chat/presentation/widget/receiver_reply_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

/// Minimal stand-in for the quoted message's sender.
class FakeSender {
  final String? firstName;
  FakeSender(this.firstName);
}

/// Minimal duck-typed stand-in for a quoted reply, exposing exactly the
/// fields ReceiverReplyQuote reads.
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
  group('ReceiverReplyQuote', () {
    testWidgets('renders the quoted sender name and text', (tester) async {
      await pumpInApp(
        tester,
        ReceiverReplyQuote(
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
        ReceiverReplyQuote(
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
