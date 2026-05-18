// Unit tests for the reply_to.dart JSON DTO.
//
// ReplyTo is a lightweight quoted-message model used when a chat message
// is a reply: it carries id, author, text and media of the original
// message, plus a nested Receiver (reused from inbox_response.dart) for
// the sender. It is a plain decoded-map DTO, so the tests are pure and
// hermetic: they pin the fromJson named constructor / toJson key mapping
// (snake_case JSON <-> camelCase Dart), round-trip stability, copyWith,
// and the model's null/missing quirks — notably that `file` is loosely
// typed (`dynamic`), that a missing/null `sender` yields null, and that
// toJson OMITS the `sender` key entirely when sender is null (rather
// than emitting `sender: null`).

import 'package:achiar_expert_app/features/chat/model/inbox_response.dart';
import 'package:achiar_expert_app/features/chat/model/reply_to.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReplyTo', () {
    final replyToMap = <String, dynamic>{
      'id': 100,
      'sender_id': 7,
      'text': 'original message',
      'file': 'https://cdn.example.com/clip.mp4',
      'media_type': 'video',
      'sender': <String, dynamic>{
        'id': 7,
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'avatar': 'https://cdn.example.com/ada.png',
        'last_activity_at': '2026-05-16T10:00:00.000Z',
      },
    };

    test('fromJson parses every field and the nested Receiver', () {
      final replyTo = ReplyTo.fromJson(replyToMap);

      expect(replyTo.id, 100);
      expect(replyTo.senderId, 7);
      expect(replyTo.text, 'original message');
      expect(replyTo.file, 'https://cdn.example.com/clip.mp4');
      expect(replyTo.mediaType, 'video');
      expect(replyTo.sender, isA<Receiver>());
      expect(replyTo.sender!.id, 7);
      expect(replyTo.sender!.firstName, 'Ada');
      expect(replyTo.sender!.lastName, 'Lovelace');
      expect(
        replyTo.sender!.lastActivityAt,
        DateTime.parse('2026-05-16T10:00:00.000Z'),
      );
    });

    test('toJson emits snake_case keys and serialized nested sender', () {
      final json = ReplyTo.fromJson(replyToMap).toJson();

      expect(json['id'], 100);
      expect(json['sender_id'], 7);
      expect(json['text'], 'original message');
      expect(json['file'], 'https://cdn.example.com/clip.mp4');
      expect(json['media_type'], 'video');
      expect(json['sender'], isA<Map<String, dynamic>>());
      expect((json['sender'] as Map)['first_name'], 'Ada');
    });

    test('round-trips through fromJson(toJson(x))', () {
      final original = ReplyTo.fromJson(replyToMap);
      final restored = ReplyTo.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.senderId, original.senderId);
      expect(restored.text, original.text);
      expect(restored.file, original.file);
      expect(restored.mediaType, original.mediaType);
      expect(restored.sender!.id, original.sender!.id);
      expect(restored.sender!.firstName, original.sender!.firstName);
    });

    test('copyWith overrides one field, leaves the rest intact', () {
      final original = ReplyTo.fromJson(replyToMap);
      final copy = original.copyWith(text: 'edited');

      expect(copy.text, 'edited');
      expect(copy.id, 100);
      expect(copy.senderId, 7);
      expect(copy.mediaType, 'video');
      expect(copy.sender!.firstName, 'Ada');
    });

    test('copyWith with no arguments preserves every field', () {
      final original = ReplyTo.fromJson(replyToMap);
      final copy = original.copyWith();

      expect(copy.id, 100);
      expect(copy.senderId, 7);
      expect(copy.text, 'original message');
      expect(copy.file, 'https://cdn.example.com/clip.mp4');
      expect(copy.mediaType, 'video');
      expect(copy.sender, same(original.sender));
    });

    test('fromJson guards a null sender with a null nested object', () {
      final replyTo = ReplyTo.fromJson(<String, dynamic>{
        'id': 1,
        'sender_id': 2,
        'sender': null,
      });

      expect(replyTo.id, 1);
      expect(replyTo.senderId, 2);
      expect(replyTo.sender, isNull);
    });

    test('toJson omits the sender key entirely when sender is null', () {
      // Quirk: toJson only adds `sender` when it is non-null, so a
      // sender-less ReplyTo produces a map WITHOUT a `sender` key
      // (rather than `sender: null`).
      final json = ReplyTo.fromJson(<String, dynamic>{
        'id': 1,
        'sender': null,
      }).toJson();

      expect(json.containsKey('sender'), isFalse);
      expect(json['id'], 1);
    });

    test('toJson keeps the other keys even when their values are null', () {
      // Only `sender` is conditionally omitted; the scalar keys are
      // always present even when null.
      final json = ReplyTo(id: 5).toJson();

      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('sender_id'), isTrue);
      expect(json.containsKey('text'), isTrue);
      expect(json.containsKey('file'), isTrue);
      expect(json.containsKey('media_type'), isTrue);
      expect(json['sender_id'], isNull);
      expect(json['text'], isNull);
    });

    test('fromJson keeps file loosely typed (dynamic)', () {
      // Quirk: `file` is `dynamic`; a non-string value passes through.
      final replyTo = ReplyTo.fromJson(<String, dynamic>{'file': null});
      expect(replyTo.file, isNull);

      final replyToInt = ReplyTo.fromJson(<String, dynamic>{'file': 42});
      expect(replyToInt.file, 42);
    });

    test('fromJson({}) tolerates an entirely empty map', () {
      final replyTo = ReplyTo.fromJson(<String, dynamic>{});

      expect(replyTo.id, isNull);
      expect(replyTo.senderId, isNull);
      expect(replyTo.text, isNull);
      expect(replyTo.file, isNull);
      expect(replyTo.mediaType, isNull);
      expect(replyTo.sender, isNull);
    });

    test('default constructor leaves every field null', () {
      final replyTo = ReplyTo();

      expect(replyTo.id, isNull);
      expect(replyTo.senderId, isNull);
      expect(replyTo.text, isNull);
      expect(replyTo.file, isNull);
      expect(replyTo.mediaType, isNull);
      expect(replyTo.sender, isNull);
    });
  });
}
