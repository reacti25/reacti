// Locks the notification-tap deep-link decoder: which chat a tapped push
// opens. FCM delivers every data value as a STRING, so the decoder must parse
// ids and fall back safely (open the app, don't crash) on anything malformed.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/all_routes.dart';
import 'package:reacti_app/helpers/notification_route.dart';

void main() {
  test('1:1 payload routes to the inbox with the sender as peer', () {
    final r = decodeNotificationRoute({
      'type': 'chat_1to1',
      'id': '42',
      'roomId': '7',
      'name': 'Avital',
      'image': 'https://x/a.jpg',
    });
    expect(r, isNotNull);
    expect(r!.route, Routes.inboxRoute);
    expect(r.args['id'], 42); // parsed to int for InboxScreen
    expect(r.args['roomId'], 7);
    expect(r.args['name'], 'Avital');
    expect(r.args['image'], 'https://x/a.jpg');
  });

  test('group payload routes to the group inbox keyed on the group id', () {
    final r = decodeNotificationRoute({
      'type': 'chat_group',
      'roomId': '15',
      'name': 'Smoke Test Group',
      'groupImage': 'https://x/g.jpg',
    });
    expect(r, isNotNull);
    expect(r!.route, Routes.groupInboxRoute);
    expect(r.args['roomId'], 15);
    expect(r.args['name'], 'Smoke Test Group');
    expect(r.args['groupImage'], 'https://x/g.jpg');
  });

  test('optional 1:1 fields default to empty when absent', () {
    final r = decodeNotificationRoute({
      'type': 'chat_1to1',
      'id': '1',
      'roomId': '2',
    });
    expect(r!.args['name'], '');
    expect(r.args['image'], '');
  });

  test('unknown type does not route (opens app normally)', () {
    expect(decodeNotificationRoute({'type': 'promo'}), isNull);
    expect(decodeNotificationRoute({}), isNull);
  });

  test('missing or non-numeric ids do not route (no crash)', () {
    expect(
      decodeNotificationRoute({'type': 'chat_1to1', 'roomId': '7'}),
      isNull, // no id
    );
    expect(
      decodeNotificationRoute({'type': 'chat_1to1', 'id': 'x', 'roomId': '7'}),
      isNull, // non-numeric id
    );
    expect(
      decodeNotificationRoute({'type': 'chat_group'}),
      isNull, // no roomId
    );
  });
}
