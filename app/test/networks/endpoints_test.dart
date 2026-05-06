// Locks the URLs the mobile client expects.
//
// If the backend renames a route, this test will fail and force us to update
// both sides together rather than discovering it in production.

import 'package:achiar_expert_app/networks/endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EndPoints — auth surface', () {
    test('login path', () {
      expect(EndPoints.login(), '/login');
    });

    test('signup path', () {
      expect(EndPoints.signup(), '/register');
    });

    test('userProfile path', () {
      expect(EndPoints.userProfile(), '/profile');
    });
  });

  group('EndPoints — chat surface (patent flow)', () {
    test('send-message path includes the receiver id', () {
      expect(EndPoints.sendMessage(42), '/auth/chat/send/42');
    });

    test('mark-viewed path includes the message id (this triggers the reaction recording on the client)', () {
      expect(EndPoints.viewInboxImage(7), '/auth/chat/mark-viewed/7');
    });

    test('group mark-viewed path', () {
      expect(EndPoints.viewGroupFile(7), '/auth/group/mark-viewed/7');
    });

    test('inbox conversation path', () {
      expect(EndPoints.inboxMessage(13), '/auth/chat/conversation/13');
    });

    test('group send path', () {
      expect(EndPoints.sendGroupMessage(99), '/auth/group/99/send');
    });
  });
}
