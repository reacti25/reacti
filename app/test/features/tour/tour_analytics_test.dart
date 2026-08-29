// The walkthrough reports which step was shown.
//
// It has been built and rebuilt for weeks on judgement alone, with no way to
// tell whether it helps. One event per step is what turns it from a yes/no into
// a funnel: which step loses people, and whether those who finish activate at a
// higher rate than those who do not.
//
// The step name is the storage flag, not an index — renumbering the walkthrough
// must not silently re-label months of history.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/tour/first_run_tour.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

/// Records what was tracked, without a network or a vendor SDK.
class _RecordingAnalytics implements AnalyticsService {
  final List<({String event, Map<String, Object?> props})> tracked = [];

  @override
  void track(String event, [Map<String, Object?> properties = const {}]) =>
      tracked.add((event: event, props: properties));

  @override
  void identify(String rawUserId) {}

  @override
  noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _RecordingAnalytics recorder;

  setUp(() async {
    await initTestGetStorage();
    FirstRunTour.resetAll();
    recorder = _RecordingAnalytics();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(recorder);
  });

  tearDown(() {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  testWidgets('showing a step reports it by name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TourMark(
            markKey: GlobalKey(),
            showOnceKey: kKeyTourAddFriendSeen,
            title: 'title',
            description: 'description',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();

    final steps =
        recorder.tracked
            .where((t) => t.event == Events.walkthroughStepShown)
            .map((t) => t.props[Props.step])
            .toList();

    expect(steps, contains(kKeyTourAddFriendSeen));
  });

  testWidgets('a step already seen reports nothing', (tester) async {
    await appData.write(kKeyTourAddFriendSeen, true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TourMark(
            markKey: GlobalKey(),
            showOnceKey: kKeyTourAddFriendSeen,
            title: 'title',
            description: 'description',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();

    // A step counted every time the screen is built would make the walkthrough
    // look far more effective than it is.
    expect(
      recorder.tracked.where((t) => t.event == Events.walkthroughStepShown),
      isEmpty,
    );
  });
}
