// Unit tests for the inbox_response.dart JSON DTOs.
//
// InboxResponse is the envelope for the one-to-one inbox endpoint. It
// nests Data (receiver, sender, room, a Chat list, pagination, block
// state), per-message Chat rows that themselves nest ReplyTo / Receiver
// / ChatRoom, the timestamped DataRoom, and Pagination. These are plain
// decoded-map DTOs, so the tests are pure and hermetic: they pin
// fromJson / toJson key mapping (snake_case JSON <-> camelCase Dart),
// round-trip stability, copyWith, and the model's null/missing quirks —
// notably that a missing `chat` key yields an EMPTY LIST rather than
// null, that the client-only fields are reset on fromJson, that
// `is_blurred` / `is_viewed` / `file` / `humanize_date` are loosely typed
// (the conversation endpoint sends `is_viewed` as a bool — see the
// chat-conversation contract), that `block_by_me` is read from snake_case
// but written as camelCase `blockByMe`, and that DateTime fields throw on
// unparseable input.

import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Receiver', () {
    final receiverMap = <String, dynamic>{
      'id': 7,
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'avatar': 'https://cdn.example.com/ada.png',
      'last_activity_at': '2026-05-16T10:00:00.000Z',
    };

    test('fromJson parses every field and the DateTime', () {
      final receiver = Receiver.fromJson(receiverMap);

      expect(receiver.id, 7);
      expect(receiver.firstName, 'Ada');
      expect(receiver.lastName, 'Lovelace');
      expect(receiver.avatar, 'https://cdn.example.com/ada.png');
      expect(receiver.lastActivityAt, isA<DateTime>());
      expect(
        receiver.lastActivityAt,
        DateTime.parse('2026-05-16T10:00:00.000Z'),
      );
    });

    test('toJson emits snake_case keys and ISO-8601 timestamp', () {
      final json = Receiver.fromJson(receiverMap).toJson();

      expect(json['id'], 7);
      expect(json['first_name'], 'Ada');
      expect(json['last_name'], 'Lovelace');
      expect(json['avatar'], 'https://cdn.example.com/ada.png');
      expect(json['last_activity_at'], isA<String>());
      expect(
        DateTime.parse(json['last_activity_at'] as String),
        DateTime.parse('2026-05-16T10:00:00.000Z'),
      );
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Receiver.fromJson(receiverMap);
      final restored = Receiver.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.firstName, original.firstName);
      expect(restored.lastActivityAt, original.lastActivityAt);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Receiver.fromJson(receiverMap);
      final copy = original.copyWith(firstName: 'Grace');

      expect(copy.firstName, 'Grace');
      expect(copy.id, 7);
      expect(copy.lastActivityAt, original.lastActivityAt);
    });

    test('fromJson keeps a null last_activity_at null', () {
      final receiver = Receiver.fromJson(<String, dynamic>{
        'id': 1,
        'last_activity_at': null,
      });

      expect(receiver.id, 1);
      expect(receiver.lastActivityAt, isNull);
    });

    test('fromJson throws on an unparseable last_activity_at', () {
      // Quirk: DateTime.parse is unguarded against bad strings.
      expect(
        () => Receiver.fromJson(<String, dynamic>{
          'last_activity_at': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final receiver = Receiver.fromJson(<String, dynamic>{});

      expect(receiver.id, isNull);
      expect(receiver.firstName, isNull);
      expect(receiver.lastName, isNull);
      expect(receiver.avatar, isNull);
      expect(receiver.lastActivityAt, isNull);
    });
  });

  group('ChatRoom', () {
    final chatRoomMap = <String, dynamic>{
      'id': 88,
      'user_one_id': 7,
      'user_two_id': 9,
    };

    test('fromJson parses every field', () {
      final room = ChatRoom.fromJson(chatRoomMap);

      expect(room.id, 88);
      expect(room.userOneId, 7);
      expect(room.userTwoId, 9);
    });

    test('toJson emits snake_case keys', () {
      final json = ChatRoom.fromJson(chatRoomMap).toJson();

      expect(json['id'], 88);
      expect(json['user_one_id'], 7);
      expect(json['user_two_id'], 9);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = ChatRoom.fromJson(chatRoomMap);
      final restored = ChatRoom.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.userOneId, original.userOneId);
      expect(restored.userTwoId, original.userTwoId);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = ChatRoom.fromJson(chatRoomMap);
      final copy = original.copyWith(id: 99);

      expect(copy.id, 99);
      expect(copy.userOneId, 7);
      expect(copy.userTwoId, 9);
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final room = ChatRoom.fromJson(<String, dynamic>{});

      expect(room.id, isNull);
      expect(room.userOneId, isNull);
      expect(room.userTwoId, isNull);
    });
  });

  group('DataRoom', () {
    final dataRoomMap = <String, dynamic>{
      'id': 88,
      'user_one_id': 7,
      'user_two_id': 9,
      'created_at': '2026-05-10T08:00:00.000Z',
      'updated_at': '2026-05-16T09:30:00.000Z',
    };

    test('fromJson parses every field and both timestamps', () {
      final room = DataRoom.fromJson(dataRoomMap);

      expect(room.id, 88);
      expect(room.userOneId, 7);
      expect(room.userTwoId, 9);
      expect(room.createdAt, DateTime.parse('2026-05-10T08:00:00.000Z'));
      expect(room.updatedAt, DateTime.parse('2026-05-16T09:30:00.000Z'));
    });

    test('toJson emits snake_case keys and ISO-8601 timestamps', () {
      final json = DataRoom.fromJson(dataRoomMap).toJson();

      expect(json['id'], 88);
      expect(json['user_one_id'], 7);
      expect(json['user_two_id'], 9);
      expect(json['created_at'], isA<String>());
      expect(json['updated_at'], isA<String>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = DataRoom.fromJson(dataRoomMap);
      final restored = DataRoom.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = DataRoom.fromJson(dataRoomMap);
      final copy = original.copyWith(id: 99);

      expect(copy.id, 99);
      expect(copy.userOneId, 7);
      expect(copy.createdAt, original.createdAt);
    });

    test('fromJson keeps null timestamps null', () {
      final room = DataRoom.fromJson(<String, dynamic>{
        'id': 1,
        'created_at': null,
        'updated_at': null,
      });

      expect(room.id, 1);
      expect(room.createdAt, isNull);
      expect(room.updatedAt, isNull);
    });

    test('fromJson throws on an unparseable created_at', () {
      // Quirk: DateTime.parse is unguarded against bad strings.
      expect(
        () => DataRoom.fromJson(<String, dynamic>{'created_at': 'bad'}),
        throwsFormatException,
      );
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final room = DataRoom.fromJson(<String, dynamic>{});

      expect(room.id, isNull);
      expect(room.userOneId, isNull);
      expect(room.userTwoId, isNull);
      expect(room.createdAt, isNull);
      expect(room.updatedAt, isNull);
    });
  });

  group('Pagination', () {
    final paginationMap = <String, dynamic>{
      'total': 50,
      'current_page': 2,
      'last_page': 5,
      'per_page': 10,
    };

    test('fromJson parses every field', () {
      final pagination = Pagination.fromJson(paginationMap);

      expect(pagination.total, 50);
      expect(pagination.currentPage, 2);
      expect(pagination.lastPage, 5);
      expect(pagination.perPage, 10);
    });

    test('toJson emits snake_case keys', () {
      final json = Pagination.fromJson(paginationMap).toJson();

      expect(json['total'], 50);
      expect(json['current_page'], 2);
      expect(json['last_page'], 5);
      expect(json['per_page'], 10);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Pagination.fromJson(paginationMap);
      final restored = Pagination.fromRawJson(original.toRawJson());

      expect(restored.total, original.total);
      expect(restored.currentPage, original.currentPage);
      expect(restored.lastPage, original.lastPage);
      expect(restored.perPage, original.perPage);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Pagination.fromJson(paginationMap);
      final copy = original.copyWith(lastPage: 99);

      expect(copy.lastPage, 99);
      expect(copy.total, 50);
      expect(copy.currentPage, 2);
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final pagination = Pagination.fromJson(<String, dynamic>{});

      expect(pagination.total, isNull);
      expect(pagination.currentPage, isNull);
      expect(pagination.lastPage, isNull);
      expect(pagination.perPage, isNull);
    });
  });

  group('ReplyTo', () {
    final replyToMap = <String, dynamic>{
      'id': 100,
      'sender_id': 7,
      'text': 'original message',
      'file': 'https://cdn.example.com/clip.mp4',
      'media_type': 'video',
      'is_blurred': 1,
      'sender': <String, dynamic>{
        'id': 7,
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'avatar': null,
        'last_activity_at': null,
      },
    };

    test('fromJson parses every field and the nested Receiver', () {
      final replyTo = ReplyTo.fromJson(replyToMap);

      expect(replyTo.id, 100);
      expect(replyTo.senderId, 7);
      expect(replyTo.text, 'original message');
      expect(replyTo.file, 'https://cdn.example.com/clip.mp4');
      expect(replyTo.mediaType, 'video');
      expect(replyTo.isBlurred, 1);
      expect(replyTo.sender, isA<Receiver>());
      expect(replyTo.sender!.firstName, 'Ada');
    });

    test('toJson emits snake_case keys and serialized nested sender', () {
      final json = ReplyTo.fromJson(replyToMap).toJson();

      expect(json['id'], 100);
      expect(json['sender_id'], 7);
      expect(json['text'], 'original message');
      expect(json['file'], 'https://cdn.example.com/clip.mp4');
      expect(json['media_type'], 'video');
      expect(json['is_blurred'], 1);
      expect(json['sender'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = ReplyTo.fromJson(replyToMap);
      final restored = ReplyTo.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.senderId, original.senderId);
      expect(restored.isBlurred, original.isBlurred);
      expect(restored.sender!.id, original.sender!.id);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = ReplyTo.fromJson(replyToMap);
      final copy = original.copyWith(text: 'edited');

      expect(copy.text, 'edited');
      expect(copy.id, 100);
      expect(copy.sender!.firstName, 'Ada');
    });

    test('fromJson guards a null sender with a null nested object', () {
      final replyTo = ReplyTo.fromJson(<String, dynamic>{
        'id': 1,
        'sender': null,
      });

      expect(replyTo.id, 1);
      expect(replyTo.sender, isNull);
    });

    test('fromJson keeps file and is_blurred loosely typed', () {
      // Quirk: both are `dynamic`; non-string / non-int values pass through.
      final replyTo = ReplyTo.fromJson(<String, dynamic>{
        'file': null,
        'is_blurred': true,
      });

      expect(replyTo.file, isNull);
      expect(replyTo.isBlurred, isTrue);
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final replyTo = ReplyTo.fromJson(<String, dynamic>{});

      expect(replyTo.id, isNull);
      expect(replyTo.senderId, isNull);
      expect(replyTo.text, isNull);
      expect(replyTo.file, isNull);
      expect(replyTo.mediaType, isNull);
      expect(replyTo.isBlurred, isNull);
      expect(replyTo.sender, isNull);
    });
  });

  group('Chat', () {
    final chatMap = <String, dynamic>{
      'id': 555,
      'sender_id': 7,
      'receiver_id': 9,
      'room_id': 88,
      'text': 'hello',
      'file': 'https://cdn.example.com/img.png',
      'status': 'sent',
      'is_blurred': 1,
      'is_viewed': 0,
      'message_type': 'reaction',
      'is_my_text': true,
      'should_show_blur': false,
      'humanize_date': '2 min ago',
      'short_text': 'hel...',
      'type': 'reaction',
      'media_type': 'image',
      'reply_to': <String, dynamic>{
        'id': 100,
        'sender_id': 9,
        'text': 'quoted',
        'file': null,
        'media_type': 'text',
        'is_blurred': 0,
        'sender': null,
      },
      'sender': <String, dynamic>{
        'id': 7,
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'avatar': null,
        'last_activity_at': null,
      },
      'receiver': <String, dynamic>{
        'id': 9,
        'first_name': 'Grace',
        'last_name': 'Hopper',
        'avatar': null,
        'last_activity_at': null,
      },
      'room': <String, dynamic>{'id': 88, 'user_one_id': 7, 'user_two_id': 9},
    };

    test('fromJson parses every field and all nested objects', () {
      final chat = Chat.fromJson(chatMap);

      expect(chat.id, 555);
      expect(chat.senderId, 7);
      expect(chat.receiverId, 9);
      expect(chat.roomId, 88);
      expect(chat.text, 'hello');
      expect(chat.file, 'https://cdn.example.com/img.png');
      expect(chat.status, 'sent');
      expect(chat.isBlurred, 1);
      expect(chat.isViewed, 0);
      expect(chat.messageType, 'reaction');
      expect(chat.isMyText, isTrue);
      expect(chat.shouldShowBlur, isFalse);
      expect(chat.humanizeDate, '2 min ago');
      expect(chat.shortText, 'hel...');
      expect(chat.type, 'reaction');
      expect(chat.mediaType, 'image');
      expect(chat.replyTo, isA<ReplyTo>());
      expect(chat.replyTo!.text, 'quoted');
      expect(chat.sender, isA<Receiver>());
      expect(chat.sender!.firstName, 'Ada');
      expect(chat.receiver, isA<Receiver>());
      expect(chat.receiver!.firstName, 'Grace');
      expect(chat.room, isA<ChatRoom>());
      expect(chat.room!.id, 88);
    });

    test('fromJson resets the client-only fields', () {
      // Quirk: server payloads never carry these, so fromJson forces
      // isLocal=false, localPath=null, uploadProgress=null even if present.
      final chat = Chat.fromJson(<String, dynamic>{
        ...chatMap,
        'isLocal': true,
        'localPath': '/tmp/x.png',
        'uploadProgress': 0.7,
      });

      expect(chat.isLocal, isFalse);
      expect(chat.localPath, isNull);
      expect(chat.uploadProgress, isNull);
    });

    test('toJson emits keys (camelCase for client-only fields)', () {
      final json = Chat.fromJson(chatMap).toJson();

      expect(json['id'], 555);
      expect(json['sender_id'], 7);
      expect(json['receiver_id'], 9);
      expect(json['room_id'], 88);
      expect(json['text'], 'hello');
      expect(json['file'], 'https://cdn.example.com/img.png');
      expect(json['status'], 'sent');
      expect(json['is_blurred'], 1);
      expect(json['is_viewed'], 0);
      expect(json['message_type'], 'reaction');
      expect(json['is_my_text'], true);
      expect(json['should_show_blur'], false);
      expect(json['humanize_date'], '2 min ago');
      expect(json['short_text'], 'hel...');
      expect(json['type'], 'reaction');
      expect(json['media_type'], 'image');
      expect(json['reply_to'], isA<Map<String, dynamic>>());
      expect(json['sender'], isA<Map<String, dynamic>>());
      expect(json['receiver'], isA<Map<String, dynamic>>());
      expect(json['room'], isA<Map<String, dynamic>>());
      // Quirk: the client-only fields all serialize under camelCase keys.
      expect(json.containsKey('isLocal'), isTrue);
      expect(json['isLocal'], isFalse);
      expect(json.containsKey('localPath'), isTrue);
      expect(json.containsKey('uploadProgress'), isTrue);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Chat.fromJson(chatMap);
      final restored = Chat.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.roomId, original.roomId);
      expect(restored.type, original.type);
      expect(restored.replyTo!.id, original.replyTo!.id);
      expect(restored.sender!.id, original.sender!.id);
      expect(restored.receiver!.id, original.receiver!.id);
      expect(restored.room!.id, original.room!.id);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Chat.fromJson(chatMap);
      final copy = original.copyWith(text: 'edited');

      expect(copy.text, 'edited');
      expect(copy.id, 555);
      expect(copy.sender!.firstName, 'Ada');
      expect(copy.room!.id, 88);
    });

    test('default constructor sets isLocal to false', () {
      // Quirk: the constructor defaults isLocal to false (a server message).
      expect(Chat().isLocal, isFalse);
    });

    test('fromJson guards null nested objects with nulls', () {
      final chat = Chat.fromJson(<String, dynamic>{
        'id': 1,
        'reply_to': null,
        'sender': null,
        'receiver': null,
        'room': null,
      });

      expect(chat.id, 1);
      expect(chat.replyTo, isNull);
      expect(chat.sender, isNull);
      expect(chat.receiver, isNull);
      expect(chat.room, isNull);
    });

    test('fromJson keeps file / is_blurred / humanize_date loosely typed', () {
      // Quirk: file, isBlurred and humanizeDate are `dynamic`.
      final chat = Chat.fromJson(<String, dynamic>{
        'file': null,
        'is_blurred': 'true',
        'humanize_date': 1234567890,
      });

      expect(chat.file, isNull);
      expect(chat.isBlurred, 'true');
      expect(chat.humanizeDate, 1234567890);
    });

    test(
      'fromJson parses a boolean is_viewed (chat-conversation contract)',
      () {
        // Regression for the private-chat "black screen": the conversation
        // endpoint sends `is_viewed` as a BOOL (see the chat-conversation
        // contract schema). The field used to be typed `int?`, so a bool
        // threw `type 'bool' is not a subtype of type 'int?'` while parsing
        // the message list — which surfaced as an error on the inbox stream
        // and left the whole screen blank. It is now loosely typed (`dynamic`),
        // matching the group `Message` model, and tolerates bool AND legacy
        // int `1`/`0`.
        final viewed = Chat.fromJson(<String, dynamic>{
          'id': 1,
          'is_viewed': true,
        });
        expect(viewed.isViewed, isTrue);

        final unviewed = Chat.fromJson(<String, dynamic>{
          'id': 2,
          'is_viewed': false,
        });
        expect(unviewed.isViewed, isFalse);

        final legacy = Chat.fromJson(<String, dynamic>{
          'id': 3,
          'is_viewed': 0,
        });
        expect(legacy.isViewed, 0);
      },
    );

    test('fromJson({}) tolerates all-missing keys', () {
      final chat = Chat.fromJson(<String, dynamic>{});

      expect(chat.id, isNull);
      expect(chat.senderId, isNull);
      expect(chat.text, isNull);
      expect(chat.replyTo, isNull);
      expect(chat.sender, isNull);
      expect(chat.receiver, isNull);
      expect(chat.room, isNull);
      expect(chat.isLocal, isFalse);
    });
  });

  group('Data', () {
    final dataMap = <String, dynamic>{
      'receiver': <String, dynamic>{
        'id': 9,
        'first_name': 'Grace',
        'last_name': 'Hopper',
        'avatar': null,
        'last_activity_at': null,
      },
      'sender': <String, dynamic>{
        'id': 7,
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'avatar': null,
        'last_activity_at': null,
      },
      'room': <String, dynamic>{
        'id': 88,
        'user_one_id': 7,
        'user_two_id': 9,
        'created_at': '2026-05-10T08:00:00.000Z',
        'updated_at': '2026-05-16T09:30:00.000Z',
      },
      'chat': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'sender_id': 7,
          'receiver_id': 9,
          'room_id': 88,
          'text': 'first',
          'type': 'normal',
        },
      ],
      'pagination': <String, dynamic>{
        'total': 1,
        'current_page': 1,
        'last_page': 1,
        'per_page': 10,
      },
      'is_blocked': false,
      'block_by_me': false,
    };

    test('fromJson parses every field and all nested objects', () {
      final data = Data.fromJson(dataMap);

      expect(data.receiver, isA<Receiver>());
      expect(data.receiver!.firstName, 'Grace');
      expect(data.sender, isA<Receiver>());
      expect(data.sender!.firstName, 'Ada');
      expect(data.room, isA<DataRoom>());
      expect(data.room!.id, 88);
      expect(data.chat, hasLength(1));
      expect(data.chat!.first.text, 'first');
      expect(data.pagination, isA<Pagination>());
      expect(data.pagination!.total, 1);
      expect(data.isBlocked, isFalse);
      expect(data.blockByMe, isFalse);
    });

    test('toJson emits keys (block_by_me read but blockByMe written)', () {
      final json = Data.fromJson(dataMap).toJson();

      expect(json['receiver'], isA<Map<String, dynamic>>());
      expect(json['sender'], isA<Map<String, dynamic>>());
      expect(json['room'], isA<Map<String, dynamic>>());
      expect(json['chat'], isA<List>());
      expect((json['chat'] as List), hasLength(1));
      expect(json['pagination'], isA<Map<String, dynamic>>());
      expect(json['is_blocked'], false);
      // Quirk: fromJson reads `block_by_me` but toJson writes `blockByMe`.
      expect(json.containsKey('blockByMe'), isTrue);
      expect(json['blockByMe'], false);
      expect(json.containsKey('block_by_me'), isFalse);
    });

    test('round-trips through fromRawJson(toRawJson(x)) loses block_by_me', () {
      // Quirk: because of the read/write key mismatch, blockByMe does NOT
      // survive a round trip — fromJson re-reads `block_by_me` (now absent).
      final original = Data.fromJson(dataMap);
      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.chat, hasLength(1));
      expect(restored.chat!.first.id, 1);
      expect(restored.receiver!.id, 9);
      expect(restored.room!.id, 88);
      expect(restored.isBlocked, isFalse);
      expect(restored.blockByMe, isNull);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Data.fromJson(dataMap);
      final copy = original.copyWith(isBlocked: true);

      expect(copy.isBlocked, isTrue);
      expect(copy.chat, same(original.chat));
      expect(copy.receiver, same(original.receiver));
    });

    test('fromJson missing chat yields an empty list, not null', () {
      // Quirk: the model defaults a missing `chat` key to [].
      final data = Data.fromJson(<String, dynamic>{'is_blocked': true});

      expect(data.chat, isNotNull);
      expect(data.chat, isEmpty);
      expect(data.receiver, isNull);
    });

    test('toJson maps a null chat list to an empty list', () {
      // Quirk: toJson emits [] when chat is null.
      final json = Data().toJson();

      expect(json['chat'], isEmpty);
    });

    test('fromJson guards null nested objects with nulls', () {
      final data = Data.fromJson(<String, dynamic>{
        'receiver': null,
        'sender': null,
        'room': null,
        'pagination': null,
      });

      expect(data.receiver, isNull);
      expect(data.sender, isNull);
      expect(data.room, isNull);
      expect(data.pagination, isNull);
    });

    test('fromJson({}) yields an empty chat list and null objects', () {
      final data = Data.fromJson(<String, dynamic>{});

      expect(data.chat, isEmpty);
      expect(data.receiver, isNull);
      expect(data.sender, isNull);
      expect(data.room, isNull);
      expect(data.pagination, isNull);
      expect(data.isBlocked, isNull);
      expect(data.blockByMe, isNull);
    });
  });

  group('InboxResponse', () {
    final responseMap = <String, dynamic>{
      'success': true,
      'message': 'Inbox fetched',
      'code': 200,
      'data': <String, dynamic>{
        'receiver': null,
        'sender': null,
        'room': null,
        'chat': <dynamic>[
          <String, dynamic>{
            'id': 9,
            'sender_id': 7,
            'text': 'hi',
            'type': 'normal',
          },
        ],
        'pagination': <String, dynamic>{
          'total': 1,
          'current_page': 1,
          'last_page': 1,
          'per_page': 20,
        },
        'is_blocked': false,
        'block_by_me': false,
      },
    };

    test('fromJson parses the envelope and nested Data', () {
      final response = InboxResponse.fromJson(responseMap);

      expect(response.success, isTrue);
      expect(response.message, 'Inbox fetched');
      expect(response.code, 200);
      expect(response.data, isA<Data>());
      expect(response.data!.chat!.first.text, 'hi');
    });

    test('toJson emits the envelope keys and serialized nested data', () {
      final json = InboxResponse.fromJson(responseMap).toJson();

      expect(json['success'], true);
      expect(json['message'], 'Inbox fetched');
      expect(json['code'], 200);
      expect(json['data'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = InboxResponse.fromJson(responseMap);
      final restored = InboxResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.chat!.first.id, 9);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = InboxResponse.fromJson(responseMap);
      final copy = original.copyWith(message: 'updated');

      expect(copy.message, 'updated');
      expect(copy.success, isTrue);
      expect(copy.data, same(original.data));
    });

    test('fromJson guards a null data with a null nested object', () {
      final response = InboxResponse.fromJson(<String, dynamic>{
        'success': false,
        'message': 'Error',
        'code': 500,
        'data': null,
      });

      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final response = InboxResponse.fromJson(<String, dynamic>{});

      expect(response.success, isNull);
      expect(response.message, isNull);
      expect(response.code, isNull);
      expect(response.data, isNull);
    });

    test('parses a populated conversation with boolean message flags', () {
      // End-to-end regression for the private-chat "black screen": a real
      // GET /auth/chat/conversation/{id} body carries messages whose
      // `is_viewed` / `is_blurred` are JSON booleans (per the
      // chat-conversation contract). Parsing this must NOT throw —
      // previously `is_viewed: false` threw a TypeError that errored the
      // inbox stream and rendered the screen blank. Mirrors the shape
      // captured from the staging backend.
      final response = InboxResponse.fromRawJson(
        '{"success":true,"message":"Messages retrieved successfully","code":200,'
        '"data":{'
        '"receiver":{"id":2,"first_name":"Smoke","last_name":"Bravo","avatar":null,"last_activity_at":"2026-05-30T21:25:58.000000Z"},'
        '"sender":{"id":1,"first_name":"Smoke","last_name":"Alpha","avatar":null,"last_activity_at":"2026-05-30T21:25:58.000000Z"},'
        '"room":{"id":1,"user_one_id":1,"user_two_id":2,"created_at":"2026-05-30T21:25:58.000000Z","updated_at":"2026-05-30T21:25:58.000000Z"},'
        '"chat":[{"id":2,"sender_id":2,"receiver_id":1,"room_id":1,"text":null,'
        '"file":"fake/path/photo.jpg","status":"read","is_blurred":true,"is_viewed":false,'
        '"message_type":"normal","is_my_text":false,"should_show_blur":true,'
        '"humanize_date":"1 second ago","short_text":null,"type":"received","media_type":"image",'
        '"reply_to":null,'
        '"sender":{"id":2,"first_name":"Smoke","last_name":"Bravo","avatar":null,"last_activity_at":"2026-05-30T21:25:58.000000Z"},'
        '"receiver":{"id":1,"first_name":"Smoke","last_name":"Alpha","avatar":null,"last_activity_at":"2026-05-30T21:25:58.000000Z"},'
        '"room":{"id":1,"user_one_id":1,"user_two_id":2}}],'
        '"pagination":{"total":1,"current_page":1,"last_page":1,"per_page":100000},'
        '"is_blocked":false,"block_by_me":false}}',
      );

      expect(response.data!.chat, hasLength(1));
      final message = response.data!.chat!.first;
      expect(message.isViewed, isFalse);
      expect(message.isBlurred, isTrue);
      expect(response.data!.isBlocked, isFalse);
    });
  });
}
