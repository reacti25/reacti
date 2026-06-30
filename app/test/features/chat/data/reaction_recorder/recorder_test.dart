// Tests for ReactionRecorder.lastFailureReason — the additive field that lets
// the widget report a granular reaction_recorded.failure_reason instead of a
// flat null_clip. record()'s return type (and the patent flow) is unchanged.
//
// Under flutter test there is no camera platform channel, so record() fails
// fast; we assert it returns null AND classifies the failure into a known enum
// value rather than leaving the reason unset.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/reaction_recorder/recorder.dart';

void main() {
  const knownReasons = {
    'camera_unavailable',
    'permission_denied',
    'init_error',
    'recording_error',
    'other',
  };

  test('a failed recording returns null and classifies the reason', () async {
    final recorder = ReactionRecorder();

    final file = await recorder.record(
      minDuration: Duration.zero,
      maxDuration: Duration.zero,
    );

    expect(file, isNull);
    expect(recorder.lastFailureReason, isNotNull);
    expect(knownReasons.contains(recorder.lastFailureReason), isTrue);
  });
}
