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

  group('self-firing marks', () {
    setUp(FirstRunTour.resetAll);

    /// A screen that shows [child] only after [show] flips, so a mark can be
    /// made to appear on a later frame the way a real one does.
    Widget host({required bool show, required Widget child}) =>
        MaterialApp(home: Scaffold(body: show ? child : const Text('loading')));

    Widget mark({String? showOnceKey}) => TourMark(
      markKey: GlobalKey(),
      showOnceKey: showOnceKey,
      title: 'title',
      description: 'description',
      child: const SizedBox(width: 40, height: 40),
    );

    testWidgets('a mark with a showOnceKey fires itself', (tester) async {
      await tester.pumpWidget(
        host(show: true, child: mark(showOnceKey: kKeyTourAttachSeen)),
      );
      await tester.pump();

      // showOnce only writes the flag once it has confirmed the target is laid
      // out, so a written flag is proof the tip actually ran.
      expect(appData.read(kKeyTourAttachSeen), isTrue);
    });

    testWidgets('a mark that appears on a later frame still fires', (
      tester,
    ) async {
      // The bug this file exists for. A chat opens on a loading skeleton and
      // the Contacts tab opens before its contacts load, so the tip's target
      // is missing on frame one. The screen used to ask exactly once, from
      // initState, and never again — so the tip never appeared at all.
      await tester.pumpWidget(
        host(show: false, child: mark(showOnceKey: kKeyTourAttachSeen)),
      );
      await tester.pump();
      expect(appData.read(kKeyTourAttachSeen), isNot(true));

      await tester.pumpWidget(
        host(show: true, child: mark(showOnceKey: kKeyTourAttachSeen)),
      );
      await tester.pump();

      expect(appData.read(kKeyTourAttachSeen), isTrue);
    });

    testWidgets('an off-screen mark waits instead of burning its flag', (
      tester,
    ) async {
      // The Contacts tab is page two of a TabBarView: it is built, and its
      // initState runs, while it is parked off to the side. Firing there would
      // spend the tip on a frame nobody saw and there would be no way to get
      // it back short of a reinstall.
      final key = GlobalKey();
      Widget page(double offset) => MaterialApp(
        home: Scaffold(
          body: Transform.translate(
            offset: Offset(offset, 0),
            child: TourMark(
              markKey: key,
              showOnceKey: kKeyTourInviteSeen,
              title: 'title',
              description: 'description',
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      await tester.pumpWidget(page(-2000));
      await tester.pump();
      expect(appData.read(kKeyTourInviteSeen), isNot(true));

      // The user swipes over to it.
      await tester.pumpWidget(page(0));
      await tester.pump();

      expect(appData.read(kKeyTourInviteSeen), isTrue);
    });

    testWidgets('a mark without a showOnceKey fires nothing', (tester) async {
      await tester.pumpWidget(host(show: true, child: mark()));
      await tester.pump();

      // The three home marks are driven by start() as a sequence; they must
      // not each pop on their own as they build.
      expect(appData.read(kKeyTourAttachSeen), isNot(true));
      expect(appData.read(kKeyTourInviteSeen), isNot(true));
    });
  });

  group('message marks', () {
    setUp(FirstRunTour.resetAll);

    test('the first message to ask gets the mark', () {
      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isTrue);
      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 2), isFalse);
    });

    test('the owner keeps the mark across rebuilds', () {
      FirstRunTour.claimMark(kKeyTourSealedSeen, 1);

      // A thread rebuilds on every keystroke and every arriving message. The
      // owner must answer the same way each time or the tip flickers.
      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isTrue);
      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isTrue);
    });

    test('the owner keeps the mark even after the flag is written', () async {
      FirstRunTour.claimMark(kKeyTourSealedSeen, 1);

      // showOnce sets the flag as the tip *opens*. Re-reading storage here
      // would unmount the target while the user is still reading it.
      await appData.write(kKeyTourSealedSeen, true);

      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isTrue);
    });

    test('an already-seen mark is never claimed on a later launch', () async {
      await appData.write(kKeyTourSealedSeen, true);

      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isFalse);
    });

    test('the two message marks are claimed independently', () {
      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 1), isTrue);

      // Same message can be both — an outgoing bubble and an incoming sealed
      // tile never are, but the flags must not share an owner slot either way.
      expect(FirstRunTour.claimMark(kKeyTourSentMediaSeen, 2), isTrue);
    });
  });

  group('just-in-time marks', () {
    setUp(() async {
      await appData.remove(kKeyTourInviteSeen);
      await appData.remove(kKeyTourAttachSeen);
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

    test('resetAll re-arms every mark, not just the home tour', () async {
      FirstRunTour.markSeen();
      await appData.write(kKeyTourInviteSeen, true);
      await appData.write(kKeyTourAttachSeen, true);

      FirstRunTour.resetAll();

      // Profile's "Replay walkthrough" depends on all three clearing: leaving
      // the just-in-time flags set would replay a third of the walkthrough
      // and there would be no way to review the rest short of reinstalling.
      expect(FirstRunTour.seen, isFalse);
      expect(appData.read(kKeyTourInviteSeen), isNot(true));
      expect(FirstRunTour.attachMarkSeen, isFalse);
    });

    test('resetAll also releases the claimed message marks', () async {
      FirstRunTour.claimMark(kKeyTourSealedSeen, 5);
      await appData.write(kKeyTourSealedSeen, true);

      FirstRunTour.resetAll();

      // Without releasing the owner, a replay would keep pointing the tip at
      // message 5 — a message that has long since been opened and is probably
      // scrolled off the screen.
      expect(FirstRunTour.claimMark(kKeyTourSealedSeen, 9), isTrue);
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
