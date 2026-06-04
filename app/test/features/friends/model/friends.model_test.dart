// Unit tests for the FriendsModel display value object.
//
// FriendsModel is a lightweight, in-app-only model with no JSON
// serialisation — these tests pin its constructor contract: all three
// fields are required and stored verbatim.

import 'package:reacti_app/features/friends/model/friends.model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FriendsModel', () {
    test('constructor stores every required field verbatim', () {
      final model = FriendsModel(
        name: 'Alice',
        username: 'alice',
        imageUrl: 'https://cdn/a.png',
      );

      expect(model.name, 'Alice');
      expect(model.username, 'alice');
      expect(model.imageUrl, 'https://cdn/a.png');
    });

    test('accepts empty strings for its fields', () {
      // The model does not validate content — empty strings are allowed.
      final model = FriendsModel(name: '', username: '', imageUrl: '');

      expect(model.name, isEmpty);
      expect(model.username, isEmpty);
      expect(model.imageUrl, isEmpty);
    });
  });
}
