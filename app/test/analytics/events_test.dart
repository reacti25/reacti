// Catalog-consistency tests: keep events.dart in lockstep with
// docs/analytics/event-catalog.md. These FAIL THE BUILD if the typed events and
// their allowlist drift — e.g. an event with no allowlist entry, an allowlist
// key that is not a real Props constant, or a global key leaking into a
// per-event feature allowlist.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/events.dart';

void main() {
  group('event catalog consistency', () {
    test('every known event has an allowlist entry', () {
      for (final event in Events.all) {
        expect(
          eventAllowlist.containsKey(event),
          isTrue,
          reason: 'Event "$event" has no eventAllowlist entry.',
        );
      }
    });

    test('every allowlist entry is a known event', () {
      for (final event in eventAllowlist.keys) {
        expect(
          Events.all.contains(event),
          isTrue,
          reason: 'Allowlist has unknown event "$event".',
        );
      }
    });

    test('every allowlisted property is a declared Props constant', () {
      final known = _knownPropKeys();
      for (final entry in eventAllowlist.entries) {
        for (final key in entry.value) {
          expect(
            known.contains(key),
            isTrue,
            reason: 'Event "${entry.key}" allows unknown property "$key".',
          );
        }
      }
    });

    test('global property keys are never listed as feature props', () {
      for (final entry in eventAllowlist.entries) {
        for (final globalKey in Props.globals) {
          expect(
            entry.value.contains(globalKey),
            isFalse,
            reason:
                'Event "${entry.key}" lists global "$globalKey" as a feature '
                'prop; globals are attached automatically.',
          );
        }
      }
    });
  });
}

/// All declared property keys (feature + global). Mirrors Props; kept explicit
/// so a typo in events.dart is caught rather than silently accepted.
Set<String> _knownPropKeys() => {
  ...Props.globals,
  Props.messageType,
  Props.scope,
  Props.sendMs,
  Props.result,
  Props.hasReply,
  Props.uploadMs,
  Props.sizeBucket,
  Props.network,
  Props.mediaKind,
  Props.deliveryMs,
  Props.coldStartMs,
  Props.isColdStart,
  Props.screen,
  Props.previousScreen,
  Props.recordMs,
  Props.failureReason,
  Props.elapsedMs,
  Props.method,
  Props.decision,
  Props.memberCountBucket,
  Props.groupSizeBucket,
};
