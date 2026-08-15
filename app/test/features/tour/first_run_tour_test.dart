// Unit tests for the first-run "how to use Reacti" tour gate
// (docs/PLAN-onboarding-walkthrough-2026-08-15.md).
//
// The overlay itself is showcaseview's job. What is ours — and what actually
// breaks a user's day if it regresses — is the once-only gate: a tour that
// re-fires on every launch is worse than no tour, and one that never fires
// leaves a new user with an empty app and no idea what to do.
//
// These tests drive the flag directly rather than mounting NavigationScreen,
// which needs Pusher, a profile stream and FCM registration to build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

void main() {
  setUp(() async {
    await initTestGetStorage();
    await appData.remove(kKeyTourSeen);
  });

  test('a fresh install has not seen the tour', () {
    expect(FirstRunTour.seen, isFalse);
  });

  test('markSeen flips the gate so it never auto-fires again', () {
    FirstRunTour.markSeen();

    expect(FirstRunTour.seen, isTrue);
    expect(appData.read(kKeyTourSeen), isTrue);
  });

  test('the gate survives a read after write, as a launch would', () async {
    FirstRunTour.markSeen();
    // Same key the next launch reads — a typo'd key would show the tour
    // forever, which is the failure mode worth pinning.
    expect(appData.read(kKeyTourSeen), isTrue);
  });

  test('start() is a no-op once seen, and does not throw uninitialised', () {
    FirstRunTour.markSeen();

    // No showcase controller is registered in a unit test; the early return on
    // `seen` is what keeps this from touching showcaseview at all.
    expect(FirstRunTour.start, returnsNormally);
  });

  test('every mark has a distinct key', () {
    final keys = {
      FirstRunTour.chatTabKey,
      FirstRunTour.friendsTabKey,
      FirstRunTour.newGroupKey,
      FirstRunTour.inviteKey,
      FirstRunTour.attachKey,
    };

    // Two marks sharing a key silently drops one step from the sequence — and
    // two of these can be mounted at once, which would be a runtime crash.
    expect(keys.length, 5);
  });

  testWidgets('a TourMark builds when no tour has been started', (
    tester,
  ) async {
    // Regression: `Showcase` throws outright if no ShowcaseView is registered,
    // and registration used to happen only inside start(). A user who had
    // already finished the home tour took the early return, registered
    // nothing, and then crashed on opening any screen carrying a mark.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TourMark(
            markKey: GlobalKey(),
            title: 'title',
            description: 'description',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  group('just-in-time marks', () {
    setUp(() async {
      await appData.remove(kKeyTourInviteSeen);
      await appData.remove(kKeyTourAttachSeen);
    });

    test('an unmounted target does NOT consume the flag', () {
      // The tab was built off-screen: nothing was shown, so the tip has to
      // survive to the visit where the user can actually see it. Burning the
      // flag here is the bug this guards.
      FirstRunTour.showOnce(
        markKey: FirstRunTour.inviteKey,
        storageKey: kKeyTourInviteSeen,
      );

      expect(appData.read(kKeyTourInviteSeen), isNot(true));
    });

    test('an already-seen mark short-circuits', () async {
      await appData.write(kKeyTourAttachSeen, true);

      expect(
        () => FirstRunTour.showOnce(
          markKey: FirstRunTour.attachKey,
          storageKey: kKeyTourAttachSeen,
        ),
        returnsNormally,
      );
      expect(FirstRunTour.attachMarkSeen, isTrue);
    });

    test('attachMarkSeen reflects the stored flag', () async {
      expect(FirstRunTour.attachMarkSeen, isFalse);

      await appData.write(kKeyTourAttachSeen, true);

      // The 1:1 composer reads this to decide whether to build the mark at
      // all; a stale `false` risks two widgets sharing one GlobalKey.
      expect(FirstRunTour.attachMarkSeen, isTrue);
    });

    test('the home tour and the JIT marks use separate flags', () async {
      FirstRunTour.markSeen();

      // One shared showcase controller drives all sequences, so this is the
      // cross-talk guard: finishing the home tour must not silently consume
      // the contextual tips.
      expect(appData.read(kKeyTourInviteSeen), isNot(true));
      expect(appData.read(kKeyTourAttachSeen), isNot(true));
    });
  });
}
