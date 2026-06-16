// Pins the authenticity overlap math (recording window vs media-exposure
// window). Pure, clock-free — the receiver widget supplies measured offsets and
// this computes the intersection that proves a reaction was captured WHILE the
// media was on screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/media_authenticity.dart';

void main() {
  group('MediaAuthenticity.compute', () {
    test('full overlap when recording sits inside a long exposure', () {
      // Media visible the whole time; 4s recording starting at t=0.
      final o = MediaAuthenticity.compute(
        recordingStartOffsetMs: 0,
        recordingDurationMs: 4000,
        mediaExposureMs: 10000,
      );
      expect(o.overlapMs, 4000);
      expect(o.overlapPct, 100);
    });

    test('partial overlap when media loads partway into the recording', () {
      // Recording started 2s BEFORE the media became visible (offset -2000),
      // so only the last 2s of the 4s recording overlapped the exposure.
      final o = MediaAuthenticity.compute(
        recordingStartOffsetMs: -2000,
        recordingDurationMs: 4000,
        mediaExposureMs: 8000,
      );
      expect(o.overlapMs, 2000);
      expect(o.overlapPct, 50);
    });

    test('overlap is capped by a short exposure', () {
      // Media hidden after 1s; recording ran 4s from t=0 → only 1s overlapped.
      final o = MediaAuthenticity.compute(
        recordingStartOffsetMs: 0,
        recordingDurationMs: 4000,
        mediaExposureMs: 1000,
      );
      expect(o.overlapMs, 1000);
      expect(o.overlapPct, 25);
    });

    test(
      'zero overlap when the recording finished before media was visible',
      () {
        // Recording window [-5000, -1000] ends before exposure starts at 0.
        final o = MediaAuthenticity.compute(
          recordingStartOffsetMs: -5000,
          recordingDurationMs: 4000,
          mediaExposureMs: 8000,
        );
        expect(o.overlapMs, 0);
        expect(o.overlapPct, 0);
      },
    );

    test('passes through the raw fields and guards a zero duration', () {
      final o = MediaAuthenticity.compute(
        recordingStartOffsetMs: 120,
        recordingDurationMs: 0,
        mediaExposureMs: 5000,
      );
      expect(o.overlapPct, 0); // no division by zero
      expect(o.recordingStartOffsetMs, 120);
      expect(o.recordingDurationMs, 0);
      expect(o.mediaExposureMs, 5000);
    });
  });
}
