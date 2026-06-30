// Pins the reaction record-window timing: at least the floor, at most the cap,
// and stop as soon as the viewer stops watching (stopEarly) in between.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';

void main() {
  const min = Duration(seconds: 5);
  const max = Duration(seconds: 20);

  test('no stopEarly → records up to the cap', () {
    fakeAsync((fa) {
      Duration? doneAt;
      reactionRecordWindow(
        minDuration: min,
        maxDuration: max,
      ).then((_) => doneAt = fa.elapsed);
      fa.elapse(const Duration(seconds: 30));
      expect(doneAt, max);
    });
  });

  test('stop mid-window → records the actual watch length', () {
    fakeAsync((fa) {
      final stop = Completer<void>();
      Duration? doneAt;
      reactionRecordWindow(
        minDuration: min,
        maxDuration: max,
        stopEarly: stop.future,
      ).then((_) => doneAt = fa.elapsed);

      fa.elapse(const Duration(seconds: 7)); // watched 7s of a 10s clip
      stop.complete();
      fa.flushMicrotasks();
      expect(doneAt, const Duration(seconds: 7));
    });
  });

  test('stop before the floor → still records the 5s minimum', () {
    fakeAsync((fa) {
      final stop = Completer<void>();
      Duration? doneAt;
      reactionRecordWindow(
        minDuration: min,
        maxDuration: max,
        stopEarly: stop.future,
      ).then((_) => doneAt = fa.elapsed);

      fa.elapse(const Duration(seconds: 2)); // bailed at 2s
      stop.complete();
      fa.elapse(const Duration(seconds: 30));
      expect(doneAt, min);
    });
  });

  test('stop never fires → capped at the max', () {
    fakeAsync((fa) {
      Duration? doneAt;
      reactionRecordWindow(
        minDuration: min,
        maxDuration: max,
        stopEarly: Completer<void>().future, // never completes
      ).then((_) => doneAt = fa.elapsed);
      fa.elapse(const Duration(seconds: 30));
      expect(doneAt, max);
    });
  });

  test('image case: min == max → fixed clip', () {
    fakeAsync((fa) {
      Duration? doneAt;
      reactionRecordWindow(
        minDuration: const Duration(seconds: 4),
        maxDuration: const Duration(seconds: 4),
      ).then((_) => doneAt = fa.elapsed);
      fa.elapse(const Duration(seconds: 10));
      expect(doneAt, const Duration(seconds: 4));
    });
  });
}
