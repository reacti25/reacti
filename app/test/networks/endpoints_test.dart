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

    test('verifySignupOtp path', () {
      expect(EndPoints.verifySignupOtp(), '/email-verify');
    });

    test('forgetPass path', () {
      expect(EndPoints.forgetPass(), '/forgot-password');
    });

    test('verifyForgetPass path', () {
      expect(EndPoints.verifyForgetPass(), '/verify-otp');
    });

    test('resendForgetOtp path', () {
      expect(EndPoints.resendForgetOtp(), '/resend-otp');
    });

    test('resetPassword path', () {
      expect(EndPoints.resetPassword(), '/reset-password');
    });

    test('logout path', () {
      expect(EndPoints.logout(), '/logout');
    });
  });

  group('EndPoints — profile surface', () {
    test('userProfile path', () {
      expect(EndPoints.userProfile(), '/profile');
    });

    test('editProfile path', () {
      expect(EndPoints.editProfile(), '/update-profile');
    });

    test('changePassword path', () {
      expect(EndPoints.changePassword(), '/update-password');
    });

    test('deleteAccount path', () {
      expect(EndPoints.deleteAccount(), '/delete-profile');
    });

    test('addToken path', () {
      expect(EndPoints.addToken(), '/firebase/token/add');
    });
  });

  group('EndPoints — friend surface', () {
    test('sendRequest path', () {
      expect(EndPoints.sendRequest(), '/friends/send-request');
    });

    test('cancelRequest path', () {
      expect(EndPoints.cancelRequest(), '/friends/cancel-request');
    });

    test('acceptRequest path', () {
      expect(EndPoints.acceptRequest(), '/friends/accept-request');
    });

    test('declineRequest path', () {
      expect(EndPoints.declineRequest(), '/friends/decline-request');
    });

    test('getRequest path', () {
      expect(EndPoints.getRequest(), '/friends/requests');
    });

    test('getSentRequestList path', () {
      expect(EndPoints.getSentRequestList(), '/friends/requests/sent/list');
    });

    test('getFriendList path', () {
      expect(EndPoints.getFriendList(), '/friends/list');
    });

    test('unfriendUser path includes id', () {
      expect(EndPoints.unfriendUser(13), '/friends/unfriend/13');
    });

    test('searchUser path includes the query', () {
      expect(EndPoints.searchUser('alice'), '/user-list?search=alice');
    });
  });

  group('EndPoints — moderation surface', () {
    test('blockedUserList path', () {
      expect(EndPoints.blockedUserList(), '/block/list');
    });

    test('blockAUser path includes id', () {
      expect(EndPoints.blockAUser(7), '/block/user/7');
    });
  });

  group('EndPoints — chat surface (patent flow)', () {
    test('chatList path', () {
      expect(EndPoints.chatList(), '/auth/chat/list');
    });

    test('deleteMessage path', () {
      expect(EndPoints.deleteMessage(), '/auth/chat/delete/chat/messages');
    });

    test('send-message path includes the receiver id', () {
      expect(EndPoints.sendMessage(42), '/auth/chat/send/42');
    });

    test('mark-viewed path includes the message id (this triggers the reaction '
        'recording on the client)', () {
      expect(EndPoints.viewInboxImage(7), '/auth/chat/mark-viewed/7');
    });

    test('inbox conversation path', () {
      expect(EndPoints.inboxMessage(13), '/auth/chat/conversation/13');
    });
  });

  group('EndPoints — group surface (patent flow)', () {
    test('createGroup path', () {
      expect(EndPoints.createGroup(), '/auth/group/create');
    });

    test('editGroup path includes id', () {
      expect(EndPoints.editGroup(5), '/auth/group/5/update');
    });

    test('group send path', () {
      expect(EndPoints.sendGroupMessage(99), '/auth/group/99/send');
    });

    test('group mark-viewed path', () {
      expect(EndPoints.viewGroupFile(7), '/auth/group/mark-viewed/7');
    });

    test('groupInbox path', () {
      expect(EndPoints.groupInbox(8), '/auth/group/8/messages');
    });

    test('groupDetails path', () {
      expect(EndPoints.groupDetails(8), '/auth/group/8');
    });

    test('groupMedia path', () {
      expect(EndPoints.groupMedia(8), '/auth/group/8/messages/media');
    });

    test('addGroupAdmin path', () {
      expect(EndPoints.addGroupAdmin(5, 9), '/auth/group/5/make-admin/9');
    });

    test('removeMember path', () {
      expect(EndPoints.removeMember(5, 9), '/auth/group/5/remove-member/9');
    });
  });

  group('EndPoints — content surface', () {
    test('getPrivacy path', () {
      expect(EndPoints.getPrivacy(), '/privacy-policy');
    });

    test('getTerms path', () {
      expect(EndPoints.getTerms(), '/terms-and-condition');
    });

    test('getFaq path', () {
      expect(EndPoints.getFaq(), '/faqs');
    });
  });
}
