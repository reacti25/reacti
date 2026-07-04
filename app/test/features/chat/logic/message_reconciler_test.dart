// Unit tests for the pure realtime message-reconciliation logic.
//
// `message_reconciler.dart` extracts the optimistic-message matching that
// previously lived inline inside the `onEvent` handlers of `InboxScreen`
// and `GroupInboxScreen`. These tests pin the behaviour so the refactor is
// provably behaviour-preserving: an incoming realtime message either
// replaces a matching optimistic local entry in place or is prepended.

import 'package:reacti_app/features/chat/logic/message_reconciler.dart';
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart' as gm;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reconcileInboxMessage', () {
    test(
      'matching optimistic text entry is replaced in place, length unchanged',
      () {
        // An optimistic local text message awaiting server confirmation.
        final optimistic = Chat(
          id: 1700000000001,
          senderId: 7,
          text: 'hello there',
          isLocal: true,
          localPath: '/tmp/local.txt',
        );
        // The confirmed server message for that same send.
        final incoming = Chat(
          id: 42,
          senderId: 7,
          text: 'hello there',
          mediaType: null,
        );

        final result = reconcileInboxMessage([optimistic], incoming);

        // The entry is reconciled in place — no growth, no insert.
        expect(result.length, 1);
        expect(result[0].id, 42);
        expect(result[0].isLocal, false);
        // The local file is preserved as a placeholder.
        expect(result[0].localPath, '/tmp/local.txt');
      },
    );

    test('no optimistic match inserts the incoming message at index 0', () {
      // A normal already-confirmed message, not optimistic.
      final existing = Chat(id: 10, senderId: 7, text: 'old message');
      final incoming = Chat(id: 99, senderId: 7, text: 'brand new');

      final result = reconcileInboxMessage([existing], incoming);

      // Length grows by one and the new message lands at the head.
      expect(result.length, 2);
      expect(result[0].id, 99);
      expect(result[1].id, 10);
    });

    test(
      'confirmed entry with identical content is not matched — inserted instead',
      () {
        // Same sender and text, but a normal id and isLocal:false: this is
        // an already-confirmed message and must NOT be treated optimistic.
        final confirmed = Chat(
          id: 55,
          senderId: 7,
          text: 'duplicate text',
          isLocal: false,
        );
        final incoming = Chat(id: 56, senderId: 7, text: 'duplicate text');

        final result = reconcileInboxMessage([confirmed], incoming);

        // Not merged — both messages remain, incoming at the head.
        expect(result.length, 2);
        expect(result[0].id, 56);
        expect(result[1].id, 55);
        expect(result[1].isLocal, false);
      },
    );

    test(
      'temporary id above 1e12 is treated as optimistic without isLocal',
      () {
        // isLocal defaults to false, but the temp id alone marks it optimistic.
        final tempIdEntry = Chat(
          id: 1700000000002,
          senderId: 7,
          text: 'sent fast',
          localPath: '/tmp/fast.txt',
        );
        final incoming = Chat(id: 70, senderId: 7, text: 'sent fast');

        final result = reconcileInboxMessage([tempIdEntry], incoming);

        expect(result.length, 1);
        expect(result[0].id, 70);
        expect(result[0].localPath, '/tmp/fast.txt');
      },
    );

    test('media message matches another media message of same type', () {
      final optimistic = Chat(
        id: 1700000000003,
        senderId: 7,
        mediaType: 'image',
        isLocal: true,
        localPath: '/tmp/photo.jpg',
      );
      final incoming = Chat(id: 80, senderId: 7, mediaType: 'image');

      final result = reconcileInboxMessage([optimistic], incoming);

      expect(result.length, 1);
      expect(result[0].id, 80);
      expect(result[0].mediaType, 'image');
      expect(result[0].localPath, '/tmp/photo.jpg');
    });

    test('sender-id mismatch prevents a match', () {
      final optimistic = Chat(
        id: 1700000000004,
        senderId: 7,
        text: 'hi',
        isLocal: true,
      );
      // Same text, different sender — must not merge.
      final incoming = Chat(id: 90, senderId: 8, text: 'hi');

      final result = reconcileInboxMessage([optimistic], incoming);

      expect(result.length, 2);
      expect(result[0].id, 90);
    });

    test('media-type mismatch prevents a match', () {
      final optimistic = Chat(
        id: 1700000000005,
        senderId: 7,
        mediaType: 'image',
        isLocal: true,
      );
      // Same sender, but the server message is a video — no match.
      final incoming = Chat(id: 91, senderId: 7, mediaType: 'video');

      final result = reconcileInboxMessage([optimistic], incoming);

      expect(result.length, 2);
      expect(result[0].id, 91);
    });

    test(
      'text-vs-text exact trimmed comparison must differ to skip a match',
      () {
        final optimistic = Chat(
          id: 1700000000006,
          senderId: 7,
          text: 'one',
          isLocal: true,
        );
        // Different text content — no match despite both being text messages.
        final incoming = Chat(id: 92, senderId: 7, text: 'two');

        final result = reconcileInboxMessage([optimistic], incoming);

        expect(result.length, 2);
        expect(result[0].id, 92);
      },
    );

    test('replyTo falls back to the optimistic entry when server omits it', () {
      // The optimistic entry carried a reply; the server event does not.
      final optimistic = Chat(
        id: 1700000000007,
        senderId: 7,
        text: 'reply body',
        isLocal: true,
        replyTo: ReplyTo(id: 5, text: 'quoted'),
      );
      final incoming = Chat(id: 93, senderId: 7, text: 'reply body');

      final result = reconcileInboxMessage([optimistic], incoming);

      expect(result.length, 1);
      // The kept reply is the fallback from the optimistic entry.
      expect(result[0].replyTo, isNotNull);
      expect(result[0].replyTo!.id, 5);
    });

    test('input list is not mutated', () {
      final optimistic = Chat(
        id: 1700000000008,
        senderId: 7,
        text: 'x',
        isLocal: true,
      );
      final input = [optimistic];
      final incoming = Chat(id: 94, senderId: 7, text: 'x');

      reconcileInboxMessage(input, incoming);

      // The caller's list is untouched — still the original optimistic entry.
      expect(input.length, 1);
      expect(input[0].id, 1700000000008);
    });
  });

  group('reconcileGroupMessage', () {
    test(
      'matching optimistic text entry is replaced in place, length unchanged',
      () {
        final optimistic = gm.Message(
          id: 1700000000001,
          senderId: 3,
          text: 'group hello',
          isLocal: true,
          localPath: '/tmp/gm.txt',
        );
        final incoming = gm.Message(id: 21, senderId: 3, text: 'group hello');

        final result = reconcileGroupMessage([optimistic], incoming);

        expect(result.length, 1);
        expect(result[0].id, 21);
        expect(result[0].isLocal, false);
        expect(result[0].localPath, '/tmp/gm.txt');
      },
    );

    test('no optimistic match inserts the incoming message at index 0', () {
      final existing = gm.Message(id: 11, senderId: 3, text: 'old');
      final incoming = gm.Message(id: 88, senderId: 3, text: 'new');

      final result = reconcileGroupMessage([existing], incoming);

      expect(result.length, 2);
      expect(result[0].id, 88);
      expect(result[1].id, 11);
    });

    test(
      'confirmed entry with identical content is not matched — inserted instead',
      () {
        final confirmed = gm.Message(
          id: 60,
          senderId: 3,
          text: 'same content',
          isLocal: false,
        );
        final incoming = gm.Message(id: 61, senderId: 3, text: 'same content');

        final result = reconcileGroupMessage([confirmed], incoming);

        expect(result.length, 2);
        expect(result[0].id, 61);
        expect(result[1].id, 60);
      },
    );

    test(
      'temporary id above 1e12 is treated as optimistic without isLocal',
      () {
        final tempIdEntry = gm.Message(
          id: 1700000000002,
          senderId: 3,
          text: 'fast group send',
          localPath: '/tmp/gfast.txt',
        );
        final incoming = gm.Message(
          id: 71,
          senderId: 3,
          text: 'fast group send',
        );

        final result = reconcileGroupMessage([tempIdEntry], incoming);

        expect(result.length, 1);
        expect(result[0].id, 71);
        expect(result[0].localPath, '/tmp/gfast.txt');
      },
    );

    test('media message matches another media message of same type', () {
      final optimistic = gm.Message(
        id: 1700000000003,
        senderId: 3,
        mediaType: 'video',
        isLocal: true,
        localPath: '/tmp/clip.mp4',
      );
      final incoming = gm.Message(id: 81, senderId: 3, mediaType: 'video');

      final result = reconcileGroupMessage([optimistic], incoming);

      expect(result.length, 1);
      expect(result[0].id, 81);
      expect(result[0].localPath, '/tmp/clip.mp4');
    });

    test('sender-id mismatch prevents a match', () {
      final optimistic = gm.Message(
        id: 1700000000004,
        senderId: 3,
        text: 'hey',
        isLocal: true,
      );
      final incoming = gm.Message(id: 95, senderId: 4, text: 'hey');

      final result = reconcileGroupMessage([optimistic], incoming);

      expect(result.length, 2);
      expect(result[0].id, 95);
    });

    test('media-type mismatch prevents a match', () {
      final optimistic = gm.Message(
        id: 1700000000005,
        senderId: 3,
        mediaType: 'image',
        isLocal: true,
      );
      final incoming = gm.Message(id: 96, senderId: 3, mediaType: 'video');

      final result = reconcileGroupMessage([optimistic], incoming);

      expect(result.length, 2);
      expect(result[0].id, 96);
    });

    test(
      'text-vs-text exact trimmed comparison must differ to skip a match',
      () {
        final optimistic = gm.Message(
          id: 1700000000006,
          senderId: 3,
          text: 'alpha',
          isLocal: true,
        );
        final incoming = gm.Message(id: 97, senderId: 3, text: 'beta');

        final result = reconcileGroupMessage([optimistic], incoming);

        expect(result.length, 2);
        expect(result[0].id, 97);
      },
    );

    test('input list is not mutated', () {
      final optimistic = gm.Message(
        id: 1700000000007,
        senderId: 3,
        text: 'y',
        isLocal: true,
      );
      final input = [optimistic];
      final incoming = gm.Message(id: 98, senderId: 3, text: 'y');

      reconcileGroupMessage(input, incoming);

      expect(input.length, 1);
      expect(input[0].id, 1700000000007);
    });
  });

  group('mergeInboxThread (re-entry / reload)', () {
    test('adopts the fresh server list even after a stale one was shown', () {
      // The bug: screen first shows a stale fetch (missing the just-sent
      // message), then the fresh fetch arrives. The merge must end on the
      // fresh list so the message is no longer hidden.
      final stale = [Chat(id: 10, senderId: 7, text: 'old')];
      final fresh = [
        Chat(id: 11, senderId: 7, text: 'my new message'),
        Chat(id: 10, senderId: 7, text: 'old'),
      ];

      final result = mergeInboxThread(stale, fresh);

      expect(result.map((c) => c.id), [11, 10]);
    });

    test(
      'keeps an in-flight optimistic entry the server does not have yet',
      () {
        final optimistic = Chat(
          id: 1700000000001,
          senderId: 7,
          text: 'uploading',
          isLocal: true,
        );
        final server = [Chat(id: 10, senderId: 7, text: 'old')];

        final result = mergeInboxThread([optimistic, ...server], server);

        // Optimistic stays at the head; server message follows; no loss.
        expect(result.length, 2);
        expect(result[0].id, 1700000000001);
        expect(result[1].id, 10);
      },
    );

    test('does not duplicate a confirmed message present on both sides', () {
      final current = [Chat(id: 11, senderId: 7, text: 'x')];
      final server = [Chat(id: 11, senderId: 7, text: 'x')];

      final result = mergeInboxThread(current, server);

      expect(result.length, 1);
      expect(result[0].id, 11);
    });
  });

  group('mergeGroupThread (re-entry / reload)', () {
    test('adopts the fresh server list even after a stale one was shown', () {
      final stale = [gm.Message(id: 10, senderId: 7, text: 'old')];
      final fresh = [
        gm.Message(id: 11, senderId: 7, text: 'my new message'),
        gm.Message(id: 10, senderId: 7, text: 'old'),
      ];

      final result = mergeGroupThread(stale, fresh);

      expect(result.map((m) => m.id), [11, 10]);
    });

    test(
      'keeps an in-flight optimistic entry the server does not have yet',
      () {
        final optimistic = gm.Message(
          id: 1700000000001,
          senderId: 7,
          text: 'uploading',
          isLocal: true,
        );
        final server = [gm.Message(id: 10, senderId: 7, text: 'old')];

        final result = mergeGroupThread([optimistic, ...server], server);

        expect(result.length, 2);
        expect(result[0].id, 1700000000001);
        expect(result[1].id, 10);
      },
    );
  });

  group('appendOlderGroupThread (scroll-to-load-older)', () {
    test('appends the older page after the current newest-first list', () {
      final current = [
        gm.Message(id: 30, senderId: 7, text: 'newest'),
        gm.Message(id: 29, senderId: 7, text: 'next'),
      ];
      final older = [
        gm.Message(id: 28, senderId: 7, text: 'older a'),
        gm.Message(id: 27, senderId: 7, text: 'older b'),
      ];

      final result = appendOlderGroupThread(current, older);

      expect(result.map((m) => m.id), [30, 29, 28, 27]);
    });

    test(
      'drops messages already present (overlapping page, no duplicates)',
      () {
        final current = [
          gm.Message(id: 30, senderId: 7, text: 'newest'),
          gm.Message(id: 29, senderId: 7, text: 'next'),
        ];
        // Page overlaps id 29 and adds 28.
        final older = [
          gm.Message(id: 29, senderId: 7, text: 'next'),
          gm.Message(id: 28, senderId: 7, text: 'older'),
        ];

        final result = appendOlderGroupThread(current, older);

        expect(result.map((m) => m.id), [30, 29, 28]);
      },
    );

    test('an empty older page leaves the list unchanged', () {
      final current = [gm.Message(id: 30, senderId: 7, text: 'only')];

      final result = appendOlderGroupThread(current, []);

      expect(result.map((m) => m.id), [30]);
    });
  });

  group('isCursorGroupResponse (ordering discriminator)', () {
    test(
      'cursor response (has_more, no per_page) is cursor → not reversed',
      () {
        // Cursor mode pagination: has_more present, full-thread keys absent.
        final pg = gm.Pagination(hasMore: true);
        expect(isCursorGroupResponse(pg), isTrue);
      },
    );

    test('full-thread response (has_more=false + per_page) is NOT cursor', () {
      // Regression: full mode sends has_more=false AND per_page. It must be
      // treated as full-thread (reversed), else a just-sent message renders off
      // the top of the reversed list and appears to vanish until re-entry.
      final pg = gm.Pagination(hasMore: false, perPage: 100000, total: 12);
      expect(isCursorGroupResponse(pg), isFalse);
    });

    test('ancient response with no pagination is NOT cursor', () {
      expect(isCursorGroupResponse(null), isFalse);
    });
  });

  group('parseRealtimeInboxChat', () {
    Map reactionEcho() => {
      'chat': {
        'id': 555,
        'sender_id': 7,
        'receiver_id': 9,
        'text': '',
        'file': 'https://example.invalid/reaction.mp4',
        'humanize_date': 'now',
        'is_blurred': 0,
        'media_type': 'video',
        'message_type': 'reaction',
        'sender': {
          'id': 7,
          'first_name': 'Bob',
          'last_name': 'B',
          'avatar': null,
        },
        'receiver': {
          'id': 9,
          'first_name': 'Alice',
          'last_name': 'A',
          'avatar': null,
        },
        'reply_to': null,
      },
    };

    test(
      'carries message_type so a received reaction is recognised as one — '
      'this gates the media sender on-play markWatched (the grey→green dot)',
      () {
        final chat = parseRealtimeInboxChat(reactionEcho());

        // The regression guard: without message_type the media sender never
        // marks the reaction watched, so the author dot never greens live.
        expect(chat.messageType, 'reaction');
        expect(chat.id, 555);
        expect(chat.senderId, 7);
        expect(chat.mediaType, 'video');
      },
    );

    test('coerces is_blurred (int/bool) to 1/0', () {
      final blurred = reactionEcho();
      (blurred['chat'] as Map)['is_blurred'] = true;
      expect(parseRealtimeInboxChat(blurred).isBlurred, 1);

      final unblurred = reactionEcho();
      (unblurred['chat'] as Map)['is_blurred'] = 0;
      expect(parseRealtimeInboxChat(unblurred).isBlurred, 0);
    });

    test('parses a nested reply_to when present', () {
      final withReply = reactionEcho();
      (withReply['chat'] as Map)['reply_to'] = {
        'id': 100,
        'sender_id': 9,
        'text': 'original',
        'file': 'https://example.invalid/photo.jpg',
        'media_type': 'image',
        'is_blurred': 1,
        'sender': null,
      };

      final chat = parseRealtimeInboxChat(withReply);

      expect(chat.replyTo, isNotNull);
      expect(chat.replyTo!.id, 100);
      expect(chat.replyTo!.mediaType, 'image');
    });
  });
}
