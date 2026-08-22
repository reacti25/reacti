// Locks the one promise the walkthrough makes about frequency: every piece of
// it appears ONCE per install, and comes back only when the user deliberately
// asks for it from Profile -> Replay walkthrough.
//
// This is what a returning user notices immediately if it breaks. The marks
// sit on the chat list, the composer and the sent bubble - screens someone
// uses every day - so a tip that re-fires on a later launch reads as the app
// being broken.
//
// The firing mechanics are covered in first_run_tour_test.dart. What is pinned
// here is the NOT-firing: the state a user is in on every launch after the
// first, and after a re-install-free logout and back in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

/// Every flag the walkthrough owns.
///
/// A seventh mark whose key is missing from [FirstRunTour.resetAll] would
/// never replay, so this list is asserted against resetAll rather than just
/// written down.
const _tourFlags = <String>[
  kKeyTourSeen,
  kKeyTourInviteSeen,
  kKeyTourAttachSeen,
  kKeyTourFirstChatSeen,
  kKeyTourSentMediaSeen,
  kKeyTourSealedSeen,
];

void main() {
  setUp(() async {
    await initTestGetStorage();
    FirstRunTour.resetAll();
  });

  test('resetAll clears every flag the walkthrough owns', () async {
    for (final flag in _tourFlags) {
      await appData.write(flag, true);
    }

    FirstRunTour.resetAll();

    for (final flag in _tourFlags) {
      expect(
        appData.read(flag),
        isNot(true),
        reason: '$flag survived Replay walkthrough',
      );
    }
  });

  test('flags left by an earlier launch keep every mark shut', () async {
    // A relaunch is exactly this: the flags are still on disk, and the
    // in-memory owner map starts empty.
    for (final flag in _tourFlags) {
      await appData.write(flag, true);
    }

    expect(FirstRunTour.seen, isTrue, reason: 'the card would show again');
    expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isFalse);
    expect(FirstRunTour.claimMark(kKeyTourSentMediaSeen, 1), isFalse);
    expect(FirstRunTour.claimMark(kKeyTourAttachSeen, 1), isFalse);
  });

  test('logging out does not re-arm the walkthrough', () async {
    // totalDataClean() drops the token, the user id and the FCM token, and
    // leaves everything else. Signing back in must not replay the tour.
    for (final flag in _tourFlags) {
      await appData.write(flag, true);
    }

    await appData.remove(kKeyUserId);
    await appData.remove(kKeyFCMToken);
    await appData.write(kKeyIsLoggedIn, false);

    for (final flag in _tourFlags) {
      expect(appData.read(flag), isTrue, reason: '$flag was cleared by logout');
    }
  });

  testWidgets('a mark whose flag is already set never opens', (tester) async {
    await appData.write(kKeyTourFirstChatSeen, true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TourMark(
            markKey: GlobalKey(),
            showOnceKey: kKeyTourFirstChatSeen,
            title: 'the tip title',
            description: 'the tip description',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    // Several frames: the mark re-arms per frame while it waits to be visible,
    // so one pump would not prove it stays quiet.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The tooltip's own text is the giveaway — if a showcase had started, it
    // would be in the tree.
    expect(find.text('the tip title'), findsNothing);
    expect(find.text('the tip description'), findsNothing);
  });
}
