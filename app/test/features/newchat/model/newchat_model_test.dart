// Unit tests for the `NewchatModel` view model.
//
// `NewchatModel` is a plain, immutable value class (no JSON serialization,
// no `copyWith`): a contact row for the new-chat screen carrying display
// data only. These tests pin the constructor wiring and field exposure.

import 'package:achiar_expert_app/features/newchat/model/newchat_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NewchatModel', () {
    test('constructor stores name, username and imageUrl', () {
      final model = NewchatModel(
        name: 'Ada Lovelace',
        username: 'ada',
        imageUrl: 'http://x/avatar.png',
      );

      expect(model.name, 'Ada Lovelace');
      expect(model.username, 'ada');
      expect(model.imageUrl, 'http://x/avatar.png');
    });

    test('fields accept empty strings', () {
      final model = NewchatModel(name: '', username: '', imageUrl: '');

      expect(model.name, isEmpty);
      expect(model.username, isEmpty);
      expect(model.imageUrl, isEmpty);
    });

    test('distinct instances keep independent field values', () {
      final a = NewchatModel(
        name: 'A',
        username: 'a',
        imageUrl: 'a.png',
      );
      final b = NewchatModel(
        name: 'B',
        username: 'b',
        imageUrl: 'b.png',
      );

      expect(a.name, 'A');
      expect(b.name, 'B');
      expect(a.username, isNot(equals(b.username)));
      expect(a.imageUrl, isNot(equals(b.imageUrl)));
    });
  });
}
