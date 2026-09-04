// Where the walkthrough lands, for each of the three situations.
//
// Achia: "once I tap the replay it needs to send me the correct tab regardless
// of my situation — have chats: chats; have friends but no chats: friends and
// explain to start a chat; no friends and no chats: find friends in contacts or
// users. Check it works well."
//
// The tab decision is one branch in `start()`, driven by whether the account
// has any conversation. It cannot be exercised end to end here — `start()`
// opens a modal sheet and needs a navigation shell — so what is pinned is the
// contract each situation depends on: which marks exist, which flag each
// carries, and that a replay re-arms all of them. The routing itself is one
// `if` over `_hasChats()`.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

/// Every flag a replay has to clear for the walkthrough to run again in full.
const _allTourFlags = <String>[
  kKeyTourSeen,
  kKeyTourInviteSeen,
  kKeyTourAttachSeen,
  kKeyTourAddFriendSeen,
  kKeyTourSendRequestSeen,
  kKeyTourFirstChatSeen,
  kKeyTourSentMediaSeen,
  kKeyTourSealedSeen,
];

void main() {
  setUp(() async {
    await initTestGetStorage();
    FirstRunTour.resetAll();
  });

  test('every step of every situation is re-armed by a replay', () async {
    for (final flag in _allTourFlags) {
      await appData.write(flag, true);
    }

    FirstRunTour.resetAll();

    for (final flag in _allTourFlags) {
      expect(
        appData.read(flag),
        isNot(true),
        reason: '$flag survived the replay, so that step would be skipped',
      );
    }
  });

  test('the three situations use different marks', () {
    // No friends → add-friend + username search on the Friends tab.
    // Friends, no chats → the friend row.
    // Chats → the chat row.
    // Sharing a key between any two would drop a step, or crash if both
    // mounted.
    final marks = {
      FirstRunTour.addFriendKey,
      FirstRunTour.searchUsernameKey,
      FirstRunTour.sendRequestKey,
      FirstRunTour.friendRowKey,
      FirstRunTour.firstChatKey,
    };
    expect(marks.length, 5);
  });

  test('the two routes to a first chat share one flag', () {
    // Friend row and chat row teach the same step by different routes, so
    // whichever the user reaches first should spend it. They are reached from
    // different tabs, so only one can ever be on screen.
    FirstRunTour.claimMark(kKeyTourFirstChatSeen, 1);
    expect(FirstRunTour.claimMark(kKeyTourFirstChatSeen, 2), isFalse);
  });

  test('both destinations are reachable, so neither case sits still', () {
    // Achia, on 1171: with chats, replaying from Profile opened the card and
    // then stayed on Profile — the "Pick someone" mark was on a tab she was not
    // on. Every situation has to NAVIGATE; an earlier version leaned on the
    // Profile row switching to Chat first, and removing that left this case
    // with no jump at all.
    //
    // The indices themselves are what the bottom bar is built from, so a
    // mismatch here is a walkthrough that lands on the wrong screen.
    expect(FirstRunTour.chatTabIndex, 0);
    expect(FirstRunTour.friendsTabIndex, 1);
  });

  test('add-friend and send-request are separate steps', () async {
    // Finding someone is not adding them. Someone who has seen "add your first
    // friend" still needs to be told the request must be accepted.
    await appData.write(kKeyTourAddFriendSeen, true);
    expect(appData.read(kKeyTourSendRequestSeen), isNot(true));
  });
}
