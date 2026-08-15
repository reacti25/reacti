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

  test('the three marks have distinct keys', () {
    final keys = {
      FirstRunTour.chatTabKey,
      FirstRunTour.friendsTabKey,
      FirstRunTour.newGroupKey,
    };

    // Two marks sharing a key silently drops one step from the sequence.
    expect(keys.length, 3);
  });
}
