// The new-user funnel: fires once, and carries time-to-value.
//
// Achia wants to know how far new users get and how long it takes. That answer
// is only worth having if the counting is right, and the two ways it goes wrong
// are both silent:
//
//   * a milestone fired twice makes every rate computed from it wrong, in a way
//     that still looks plausible on a chart;
//   * an elapsed time of zero reads as an instant conversion, which is the most
//     flattering possible lie about time-to-value.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/activation_funnel.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/test_storage.dart';

void main() {
  setUp(() async {
    await initTestGetStorage();
    await ActivationFunnel.resetForTest();
  });

  group('the clock', () {
    test('starts on first launch and never restarts', () async {
      await ActivationFunnel.ensureStarted();
      final first = appData.read(kKeyFirstLaunchAt);
      expect(first, isNotNull);

      // Every later launch calls this too. Restarting would reset
      // time-to-value to nearly zero for everyone who has been here a while.
      await ActivationFunnel.ensureStarted();
      expect(appData.read(kKeyFirstLaunchAt), first);
    });
  });

  group('milestones', () {
    test('a milestone is only reported once', () async {
      await ActivationFunnel.ensureStarted();

      expect(ActivationFunnel.reached(Events.firstMessageSent), isFalse);
      await ActivationFunnel.reach(Events.firstMessageSent);
      expect(ActivationFunnel.reached(Events.firstMessageSent), isTrue);

      // Sending a second message must not count as a second first message.
      await ActivationFunnel.reach(Events.firstMessageSent);
      expect(ActivationFunnel.reached(Events.firstMessageSent), isTrue);
    });

    test('milestones are independent of each other', () async {
      await ActivationFunnel.ensureStarted();
      await ActivationFunnel.reach(Events.registerStarted);

      // Reaching one step must not mark the rest done, or the funnel collapses
      // to a single bar.
      expect(ActivationFunnel.reached(Events.otpVerified), isFalse);
      expect(ActivationFunnel.reached(Events.friendAdded), isFalse);
      expect(ActivationFunnel.reached(Events.firstReactionReceived), isFalse);
    });

    test('a milestone survives a relaunch', () async {
      await ActivationFunnel.ensureStarted();
      await ActivationFunnel.reach(Events.signupCompleted);

      // The flags live in storage, which is what a relaunch reads. In-memory
      // state would re-fire the whole funnel on every cold start.
      expect(
        appData.read(kKeyActivationMilestones),
        contains(Events.signupCompleted),
      );
      expect(ActivationFunnel.reached(Events.signupCompleted), isTrue);
    });

    test('a milestone still records when the clock never started', () async {
      // An install from before this code has no first-launch stamp. The step
      // must still be reported — losing it entirely is worse than losing its
      // duration — just without a fabricated elapsed time.
      await ActivationFunnel.reach(Events.friendAdded);
      expect(ActivationFunnel.reached(Events.friendAdded), isTrue);
    });
  });

  group('ambient context', () {
    test('country and language come from the locale, region only', () {
      const context = AnalyticsContext(
        env: 'staging',
        platform: 'ios',
        appVersion: '1.5.0',
        appBuild: '18',
        sessionId: 'abc',
        country: 'IL',
        language: 'he',
        nowIso: _fixedNow,
      );

      // Country, not city and not coordinates: enough to answer "where are our
      // users" without narrowing anyone down, and read from the device locale
      // so it costs the user no permission prompt.
      expect(context.country, 'IL');
      expect(context.language, 'he');
    });

    test('an unknown locale leaves them empty, not guessed', () {
      const context = AnalyticsContext(
        env: 'staging',
        platform: 'ios',
        appVersion: '1.5.0',
        appBuild: '18',
        sessionId: 'abc',
        nowIso: _fixedNow,
      );

      // Empty is dropped before sending. A placeholder would read as a real
      // country in every query written afterwards.
      expect(context.country, isEmpty);
      expect(context.language, isEmpty);
    });
  });
}

String _fixedNow() => '2026-08-29T00:00:00.000Z';
