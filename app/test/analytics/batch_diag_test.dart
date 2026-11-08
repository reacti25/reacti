import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/batch_diag.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/helpers/di.dart';

import '../support/fake_analytics_service.dart';

void main() {
  late FakeAnalyticsService fake;

  setUp(() {
    fake = FakeAnalyticsService();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(fake);
  });

  tearDown(() {
    locator.unregister<AnalyticsService>();
    batchDiagEnabled = false;
  });

  test('sends nothing outside staging', () {
    batchDiagEnabled = false;
    batchDiag('group', 'event', 'x');
    batchDiagDraw('group', 1, 'image', 'hello');
    batchDiagRows('group', 3);
    expect(fake.events, isEmpty);
  });

  test('sends a step with its allowlisted properties on staging', () {
    batchDiagEnabled = true;
    batchDiag('group', 'insert', 'n=1');
    final props = fake.propsOf(Events.batchDiag)!;
    expect(props[Props.scope], 'group');
    expect(props[Props.diagStep], 'insert');
    expect(props[Props.diagDetail], 'n=1');
    expect(props[Props.diagSeq], isA<int>());
  });

  test('a snapshot carries text lengths, never the text', () {
    final snap = batchDiagSnap([
      (1700000000001234, 'image', 'secret caption'),
      (42, null, null),
    ]);
    expect(snap, 'n=2 T1234:image:14,42:text:0');
    expect(snap, isNot(contains('secret')));
  });

  test('a bubble logs once, and rows only when the count changes', () {
    batchDiagEnabled = true;
    batchDiagDraw('private', 7, 'image', '');
    batchDiagDraw('private', 7, 'image', '');
    batchDiagRows('private', 9);
    batchDiagRows('private', 9);
    expect(fake.countOf(Events.batchDiag), 2);
  });
}
