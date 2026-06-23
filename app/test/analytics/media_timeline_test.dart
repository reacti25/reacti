// Pins the tap-anchored timeline math (tap → mark-viewed → media-ready →
// painted → record-start). Pure, clock-free — the receiver widget captures the
// timestamps and this turns them into per-segment millisecond offsets that form
// the Phase-0 baseline for the trigger-on-paint work.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/media_timeline.dart';

void main() {
  group('MediaTimeline.fromTimestamps', () {
    final tap = DateTime(2026, 6, 23, 12, 0, 0);

    test('computes each segment offset relative to the tap', () {
      final t = MediaTimeline.fromTimestamps(
        tapAt: tap,
        markViewedAt: tap.add(const Duration(milliseconds: 300)),
        mediaReadyAt: tap.add(const Duration(milliseconds: 1200)),
        paintedAt: tap.add(const Duration(milliseconds: 1250)),
        recordStartAt: tap.add(const Duration(milliseconds: 320)),
      );

      expect(t.markViewedMs, 300);
      expect(t.mediaReadyMs, 1200);
      expect(t.paintedMs, 1250);
      expect(t.recordStartMs, 320);
    });

    test('leaves segments that never happened null', () {
      // Media opened (mark-viewed) but never finished decoding/painting and no
      // recording started — only the mark-viewed segment is known.
      final t = MediaTimeline.fromTimestamps(
        tapAt: tap,
        markViewedAt: tap.add(const Duration(milliseconds: 250)),
      );

      expect(t.markViewedMs, 250);
      expect(t.mediaReadyMs, isNull);
      expect(t.paintedMs, isNull);
      expect(t.recordStartMs, isNull);
    });

    test('tap with no segments yields an all-null timeline', () {
      final t = MediaTimeline.fromTimestamps(tapAt: tap);
      expect(t.markViewedMs, isNull);
      expect(t.mediaReadyMs, isNull);
      expect(t.paintedMs, isNull);
      expect(t.recordStartMs, isNull);
    });
  });
}
