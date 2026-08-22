// Unit tests for the group_inbox_response.dart JSON DTOs.
//
// GroupInboxResponse is the envelope for the group-conversation inbox
// endpoint. It nests Data (messages + pagination), a list of Message
// rows, and per-message Group / Sender / ReplyTo objects plus a
// Pagination block. These are plain decoded-map DTOs, so the tests are
// pure and hermetic: they pin fromJson / toJson key mapping (snake_case
// JSON <-> camelCase Dart), round-trip stability, copyWith, and the
// model's null/missing quirks — notably that a missing `messages` key
// yields an EMPTY LIST rather than null, that the client-only fields
// (isLocal/localPath/uploadProgress) are reset on fromJson, that
// `isLocal` is serialized under the camelCase key `isLocal`, and that
// `is_blurred` / `is_viewed` are loosely typed (int / bool / string).

import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sender', () {
    final senderMap = <String, dynamic>{
      'id': 7,
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'avatar': 'https://cdn.example.com/ada.png',
    };

    test('fromJson parses every field', () {
      final sender = Sender.fromJson(senderMap);

      expect(sender.id, 7);
      expect(sender.firstName, 'Ada');
      expect(sender.lastName, 'Lovelace');
      expect(sender.avatar, 'https://cdn.example.com/ada.png');
    });

    test('toJson emits snake_case keys', () {
      final json = Sender.fromJson(senderMap).toJson();

      expect(json['id'], 7);
      expect(json['first_name'], 'Ada');
      expect(json['last_name'], 'Lovelace');
      expect(json['avatar'], 'https://cdn.example.com/ada.png');
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Sender.fromJson(senderMap);
      final restored = Sender.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.firstName, original.firstName);
      expect(restored.lastName, original.lastName);
      expect(restored.avatar, original.avatar);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Sender.fromJson(senderMap);
      final copy = original.copyWith(firstName: 'Grace');

      expect(copy.firstName, 'Grace');
      expect(copy.id, 7);
      expect(copy.lastName, 'Lovelace');
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final sender = Sender.fromJson(<String, dynamic>{});

      expect(sender.id, isNull);
      expect(sender.firstName, isNull);
      expect(sender.lastName, isNull);
      expect(sender.avatar, isNull);
    });
  });

  group('Group', () {
    final groupMap = <String, dynamic>{
      'id': 42,
      'name': 'Engineering',
      'avatar': 'https://cdn.example.com/eng.png',
    };

    test('fromJson parses every field', () {
      final groupModel = Group.fromJson(groupMap);

      expect(groupModel.id, 42);
      expect(groupModel.name, 'Engineering');
      expect(groupModel.avatar, 'https://cdn.example.com/eng.png');
    });

    test('toJson emits snake_case keys', () {
      final json = Group.fromJson(groupMap).toJson();

      expect(json['id'], 42);
      expect(json['name'], 'Engineering');
      expect(json['avatar'], 'https://cdn.example.com/eng.png');
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Group.fromJson(groupMap);
      final restored = Group.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.avatar, original.avatar);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Group.fromJson(groupMap);
      final copy = original.copyWith(name: 'Renamed');

      expect(copy.name, 'Renamed');
      expect(copy.id, 42);
      expect(copy.avatar, 'https://cdn.example.com/eng.png');
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final groupModel = Group.fromJson(<String, dynamic>{});

      expect(groupModel.id, isNull);
      expect(groupModel.name, isNull);
      expect(groupModel.avatar, isNull);
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
      },
    };

    test('fromJson parses every field and the nested Sender', () {
      final replyTo = ReplyTo.fromJson(replyToMap);

      expect(replyTo.id, 100);
      expect(replyTo.senderId, 7);
      expect(replyTo.text, 'original message');
      expect(replyTo.file, 'https://cdn.example.com/clip.mp4');
      expect(replyTo.mediaType, 'video');
      expect(replyTo.isBlurred, 1);
      expect(replyTo.sender, isA<Sender>());
      expect(replyTo.sender!.firstName, 'Ada');
    });

    test('toJson emits snake_case keys and serialized nested Sender', () {
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
      expect(restored.mediaType, original.mediaType);
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

    test('fromJson keeps is_blurred loosely typed (bool / string)', () {
      // Quirk: is_blurred is `dynamic`; the model passes it through as-is.
      expect(
        ReplyTo.fromJson(<String, dynamic>{'is_blurred': true}).isBlurred,
        isTrue,
      );
      expect(
        ReplyTo.fromJson(<String, dynamic>{'is_blurred': '0'}).isBlurred,
        '0',
      );
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

  group('Message', () {
    final messageMap = <String, dynamic>{
      'id': 555,
      'group_id': 42,
      'sender_id': 7,
      'text': 'hello group',
      'file': 'https://cdn.example.com/img.png',
      'status': 'sent',
      'is_blurred': 1,
      'is_viewed': 0,
      'message_type': 'reaction',
      'created_at': '2026-05-16 10:00:00',
      'media_type': 'image',
      'sender': <String, dynamic>{
        'id': 7,
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'avatar': null,
      },
      'group': <String, dynamic>{
        'id': 42,
        'name': 'Engineering',
        'avatar': null,
      },
      'reply_to': <String, dynamic>{
        'id': 100,
        'sender_id': 9,
        'text': 'quoted',
        'file': null,
        'media_type': 'text',
        'is_blurred': 0,
        'sender': null,
      },
    };

    test('fromJson parses every field and all nested objects', () {
      final message = Message.fromJson(messageMap);

      expect(message.id, 555);
      expect(message.groupId, 42);
      expect(message.senderId, 7);
      expect(message.text, 'hello group');
      expect(message.file, 'https://cdn.example.com/img.png');
      expect(message.status, 'sent');
      expect(message.isBlurred, 1);
      expect(message.isViewed, 0);
      expect(message.messageType, 'reaction');
      expect(message.createdAt, '2026-05-16 10:00:00');
      expect(message.mediaType, 'image');
      expect(message.sender, isA<Sender>());
      expect(message.sender!.firstName, 'Ada');
      expect(message.group, isA<Group>());
      expect(message.group!.name, 'Engineering');
      expect(message.replyTo, isA<ReplyTo>());
      expect(message.replyTo!.text, 'quoted');
    });

    test('fromJson resets the client-only fields', () {
      // Quirk: server payloads never carry these, so fromJson forces
      // isLocal=false, localPath=null, uploadProgress=null even if present.
      final message = Message.fromJson(<String, dynamic>{
        ...messageMap,
        'isLocal': true,
        'local_path': '/tmp/x.png',
        'upload_progress': 0.5,
      });

      expect(message.isLocal, isFalse);
      expect(message.localPath, isNull);
      expect(message.uploadProgress, isNull);
    });

    test('toJson emits snake_case keys but camelCase isLocal', () {
      final json = Message.fromJson(messageMap).toJson();

      expect(json['id'], 555);
      expect(json['group_id'], 42);
      expect(json['sender_id'], 7);
      expect(json['text'], 'hello group');
      expect(json['file'], 'https://cdn.example.com/img.png');
      expect(json['status'], 'sent');
      expect(json['is_blurred'], 1);
      expect(json['is_viewed'], 0);
      expect(json['message_type'], 'reaction');
      expect(json['created_at'], '2026-05-16 10:00:00');
      expect(json['media_type'], 'image');
      expect(json['sender'], isA<Map<String, dynamic>>());
      expect(json['group'], isA<Map<String, dynamic>>());
      expect(json['reply_to'], isA<Map<String, dynamic>>());
      // Quirk: isLocal serializes under camelCase 'isLocal', while
      // localPath / uploadProgress use snake_case keys.
      expect(json.containsKey('isLocal'), isTrue);
      expect(json['isLocal'], isFalse);
      expect(json.containsKey('local_path'), isTrue);
      expect(json.containsKey('upload_progress'), isTrue);
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Message.fromJson(messageMap);
      final restored = Message.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.groupId, original.groupId);
      expect(restored.messageType, original.messageType);
      expect(restored.sender!.id, original.sender!.id);
      expect(restored.group!.id, original.group!.id);
      expect(restored.replyTo!.id, original.replyTo!.id);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Message.fromJson(messageMap);
      final copy = original.copyWith(text: 'edited');

      expect(copy.text, 'edited');
      expect(copy.id, 555);
      expect(copy.sender!.firstName, 'Ada');
      expect(copy.group!.name, 'Engineering');
    });

    test('default constructor sets isLocal to false', () {
      // Quirk: the constructor defaults isLocal to false (a server message).
      expect(Message().isLocal, isFalse);
    });

    test('fromJson guards null nested objects with nulls', () {
      final message = Message.fromJson(<String, dynamic>{
        'id': 1,
        'sender': null,
        'group': null,
        'reply_to': null,
      });

      expect(message.id, 1);
      expect(message.sender, isNull);
      expect(message.group, isNull);
      expect(message.replyTo, isNull);
    });

    test('fromJson keeps is_blurred / is_viewed loosely typed', () {
      // Quirk: both are `dynamic` and pass the raw value through.
      final message = Message.fromJson(<String, dynamic>{
        'is_blurred': true,
        'is_viewed': 'yes',
      });

      expect(message.isBlurred, isTrue);
      expect(message.isViewed, 'yes');
    });

    test('fromJson({}) tolerates all-missing keys', () {
      final message = Message.fromJson(<String, dynamic>{});

      expect(message.id, isNull);
      expect(message.groupId, isNull);
      expect(message.text, isNull);
      expect(message.sender, isNull);
      expect(message.group, isNull);
      expect(message.replyTo, isNull);
      expect(message.isLocal, isFalse);
    });

    test('react-to-unlock: parses viewer_has_reacted / reactions_waiting', () {
      final locked = Message.fromJson(<String, dynamic>{
        'id': 1,
        'viewer_has_reacted': false,
        'reactions_waiting': 3,
      });
      expect(locked.viewerHasReacted, isFalse);
      expect(locked.reactionsWaiting, 3);

      final json = locked.toJson();
      expect(json['viewer_has_reacted'], isFalse);
      expect(json['reactions_waiting'], 3);
    });

    test('react-to-unlock: missing gate fields fail open (unlocked, 0)', () {
      // An older backend omits both keys — the message must NOT lock (default
      // viewerHasReacted=true) and show no waiting count.
      final message = Message.fromJson(<String, dynamic>{'id': 1});
      expect(message.viewerHasReacted, isTrue);
      expect(message.reactionsWaiting, 0);
    });
  });

  group('Data', () {
    final dataMap = <String, dynamic>{
      'messages': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'group_id': 42,
          'sender_id': 7,
          'text': 'first',
          'message_type': 'normal',
        },
      ],
      'pagination': <String, dynamic>{
        'total': 1,
        'current_page': 1,
        'last_page': 1,
        'per_page': 10,
      },
    };

    test('fromJson parses the messages list and pagination', () {
      final data = Data.fromJson(dataMap);

      expect(data.messages, hasLength(1));
      expect(data.messages!.first.text, 'first');
      expect(data.pagination, isA<Pagination>());
      expect(data.pagination!.total, 1);
    });

    test('toJson emits snake_case keys with serialized list', () {
      final json = Data.fromJson(dataMap).toJson();

      expect(json['messages'], isA<List>());
      expect((json['messages'] as List), hasLength(1));
      expect(json['pagination'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = Data.fromJson(dataMap);
      final restored = Data.fromRawJson(original.toRawJson());

      expect(restored.messages, hasLength(1));
      expect(restored.messages!.first.id, 1);
      expect(restored.pagination!.total, 1);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = Data.fromJson(dataMap);
      final copy = original.copyWith(messages: <Message>[]);

      expect(copy.messages, isEmpty);
      expect(copy.pagination, same(original.pagination));
    });

    test('fromJson missing messages yields an empty list, not null', () {
      // Quirk: the model defaults a missing `messages` key to [].
      final data = Data.fromJson(<String, dynamic>{'pagination': null});

      expect(data.messages, isNotNull);
      expect(data.messages, isEmpty);
      expect(data.pagination, isNull);
    });

    test('toJson maps a null messages list to an empty list', () {
      // Quirk: toJson emits [] when messages is null.
      final json = Data(messages: null, pagination: null).toJson();

      expect(json['messages'], isEmpty);
      expect(json['pagination'], isNull);
    });

    test('fromJson({}) yields an empty list and null pagination', () {
      final data = Data.fromJson(<String, dynamic>{});

      expect(data.messages, isEmpty);
      expect(data.pagination, isNull);
    });
  });

  group('GroupInboxResponse', () {
    final responseMap = <String, dynamic>{
      'success': true,
      'message': 'Messages fetched',
      'code': 200,
      'data': <String, dynamic>{
        'messages': <dynamic>[
          <String, dynamic>{
            'id': 9,
            'group_id': 42,
            'sender_id': 7,
            'text': 'hi',
            'message_type': 'normal',
          },
        ],
        'pagination': <String, dynamic>{
          'total': 1,
          'current_page': 1,
          'last_page': 1,
          'per_page': 20,
        },
      },
    };

    test('fromJson parses the envelope and nested Data', () {
      final response = GroupInboxResponse.fromJson(responseMap);

      expect(response.success, isTrue);
      expect(response.message, 'Messages fetched');
      expect(response.code, 200);
      expect(response.data, isA<Data>());
      expect(response.data!.messages!.first.text, 'hi');
    });

    test('toJson emits the envelope keys and serialized nested data', () {
      final json = GroupInboxResponse.fromJson(responseMap).toJson();

      expect(json['success'], true);
      expect(json['message'], 'Messages fetched');
      expect(json['code'], 200);
      expect(json['data'], isA<Map<String, dynamic>>());
    });

    test('round-trips through fromRawJson(toRawJson(x))', () {
      final original = GroupInboxResponse.fromJson(responseMap);
      final restored = GroupInboxResponse.fromRawJson(original.toRawJson());

      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.code, original.code);
      expect(restored.data!.messages!.first.id, 9);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = GroupInboxResponse.fromJson(responseMap);
      final copy = original.copyWith(message: 'updated');

      expect(copy.message, 'updated');
      expect(copy.success, isTrue);
      expect(copy.data, same(original.data));
    });

    test('fromJson guards a null data with a null nested object', () {
      final response = GroupInboxResponse.fromJson(<String, dynamic>{
        'success': false,
        'message': 'Error',
        'code': 500,
        'data': null,
      });

      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final response = GroupInboxResponse.fromJson(<String, dynamic>{});

      expect(response.success, isNull);
      expect(response.message, isNull);
      expect(response.code, isNull);
      expect(response.data, isNull);
    });
  });
}
