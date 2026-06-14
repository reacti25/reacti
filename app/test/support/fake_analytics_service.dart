// Shared test fake for AnalyticsService.
//
// Records every dispatched (event, properties) so instrumentation tests can
// assert that a flow emits the right event with the right allowlisted props,
// without any network. Uses a fixed AnalyticsContext so the global properties
// (env/platform/session/ts) are deterministic in assertions.
//
// This is the repo's hand-written-fake pattern (no mocking package): it extends
// the real AnalyticsService, so the allowlist + identity logic under test is the
// real base-class logic — only dispatch is captured.

import 'package:reacti_app/analytics/analytics_service.dart';

/// A single captured analytics event.
class TrackedEvent {
  TrackedEvent(this.name, this.props);

  final String name;
  final Map<String, Object?> props;
}

/// Fixed context so global props are deterministic in tests.
const AnalyticsContext kTestAnalyticsContext = AnalyticsContext(
  env: 'staging',
  platform: 'ios',
  appVersion: '1.1.0',
  appBuild: '11',
  sessionId: 'test-session',
  nowIso: _fixedNow,
);

String _fixedNow() => '2026-06-15T00:00:00.000Z';

/// Records dispatched events for assertions.
class FakeAnalyticsService extends AnalyticsService {
  FakeAnalyticsService({AnalyticsContext? context, super.hashSalt})
    : super(context: context ?? kTestAnalyticsContext);

  /// Every event captured, in order.
  final List<TrackedEvent> events = [];

  @override
  void dispatch(String event, Map<String, Object?> properties) {
    events.add(
      TrackedEvent(event, Map<String, Object?>.unmodifiable(properties)),
    );
  }

  /// The most recently captured event, or null if none.
  TrackedEvent? get last => events.isEmpty ? null : events.last;

  /// How many times [name] was tracked.
  int countOf(String name) => events.where((e) => e.name == name).length;

  /// The props of the first captured [name] event, or null.
  Map<String, Object?>? propsOf(String name) {
    for (final e in events) {
      if (e.name == name) return e.props;
    }
    return null;
  }
}
