// Regression guard for the "all videos turn black after ~a minute" bug.
//
// Each cached FlickManager eagerly initializes its VideoPlayerController — an
// AVPlayer on iOS — and iOS has a hard limit on simultaneous video decoders
// (~16 render pipelines). With the old cap of 50, scrolling + realtime prefetch
// + inbox precache accumulated initialized players past that limit, at which
// point iOS refused to decode and EVERY video rendered black at once.
//
// The full eviction/LRU behaviour needs the video_player platform channel, so
// it isn't unit-testable here; this pins the load-bearing invariant — the cap
// must stay well under iOS's limit so the regression can't creep back.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/video_controller_cache.dart';

void main() {
  test('cache cap stays well under iOS simultaneous-decoder limit', () {
    expect(VideoControllerCache.maxCachedVideos, greaterThan(0));
    // Comfortably below iOS's ~16 concurrent-AVPlayer ceiling.
    expect(VideoControllerCache.maxCachedVideos, lessThanOrEqualTo(12));
  });
}
