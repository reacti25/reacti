// Pins how the group thread folds reactions under their originals (one
// framed cluster per media). The list is newest-first; a reaction leaves its
// chronological slot and joins its original's row, oldest-first, unless the
// original is not loaded, in which case it stays a plain row.

import 'package:reacti_app/features/chat/logic/group_thread_rows.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:flutter_test/flutter_test.dart';

Message _media(int id) =>
    Message(id: id, senderId: 1, mediaType: 'image', file: 'f$id.jpg');

Message _text(int id) => Message(id: id, senderId: 1, text: 'msg $id');

Message _reaction(int id, {required int to, int sender = 2}) => Message(
  id: id,
  senderId: sender,
  mediaType: 'video',
  messageType: 'reaction',
  replyTo: ReplyTo(id: to, senderId: 1),
);

void main() {
  test('reactions fold under their original, oldest-first', () {
    // Newest-first: Dana's reaction, a text, Bob's reaction, the photo.
    final rows = buildGroupThreadRows([
      _reaction(14, to: 10, sender: 3),
      _text(12),
      _reaction(11, to: 10, sender: 2),
      _media(10),
    ]);

    expect(rows.map((r) => r.message.id), [12, 10]);
    expect(rows[1].reactions.map((r) => r.id), [11, 14]);
    expect(rows[0].reactions, isEmpty);
  });

  test('a reaction whose original is not loaded stays a plain row', () {
    final rows = buildGroupThreadRows([_reaction(20, to: 5), _media(10)]);

    expect(rows.map((r) => r.message.id), [20, 10]);
    expect(rows[0].reactions, isEmpty);
  });

  test('two media keep their own reactions apart', () {
    final rows = buildGroupThreadRows([
      _reaction(33, to: 30),
      _reaction(23, to: 20),
      _media(30),
      _reaction(22, to: 20),
      _media(20),
    ]);

    expect(rows.map((r) => r.message.id), [30, 20]);
    expect(rows[0].reactions.map((r) => r.id), [33]);
    expect(rows[1].reactions.map((r) => r.id), [22, 23]);
  });

  test('an optimistic reaction (temp id) joins the cluster', () {
    final rows = buildGroupThreadRows([
      _reaction(1700000000001, to: 10, sender: 1),
      _media(10),
    ]);

    expect(rows.length, 1);
    expect(rows[0].reactions.single.id, 1700000000001);
  });

  test('a list without reactions is unchanged', () {
    final rows = buildGroupThreadRows([_text(2), _media(1)]);

    expect(rows.map((r) => r.message.id), [2, 1]);
    expect(rows.every((r) => r.reactions.isEmpty), isTrue);
  });
}
