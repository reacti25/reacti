# Root-cause analysis — "all videos freeze after ~1 minute"

**Date:** 2026-07-07
**Reporter:** Achia (on-device, staging TestFlight)
**Status:** Root cause identified + fixed (candidate); restore build shipped first.

## Symptom

Chat videos (including reaction videos) play fine for a short time, then after
roughly a minute **all/most videos freeze at once** — the frame stops updating
(or goes black). It's time/usage-based (accumulates), affects everything
simultaneously, and it is **pre-existing** — it reproduced on a build with the
whole media-performance batch reverted.

## What it is NOT (ruled out with code evidence)

Two rounds of investigation ruled these out:

- **A ~60s timer / polling** — none exists in the chat, video, or network code.
- **Expiring/signed media URLs** — URLs are plain static `https://…/uploads/…mp4`;
  no token, signature, or query expiry.
- **Auth-token refresh on a timer** — token is read once at init; no periodic
  refresh; 401 → logout, not black video.
- **Pusher reconnect / app-lifecycle disposal / global cache-clear** — the
  realtime error handler only refreshes the socket; chat screens don't observe
  app lifecycle; `VideoControllerCache.clear()` is commented out.
- **iOS decoder-count exhaustion (my first wrong guess).** I capped the video
  cache from 50 → 6 players (well under iOS's ~16-decoder limit). **It did not
  fix the freeze.** That's the key negative result: with only 6 players it still
  froze, so raw *count* of players is not the binding constraint. (That change
  was reverted.)

## The actual root cause — a listener leak on the shared controller

`VideoControllerCache` returns **one shared `FlickManager` (and
`VideoPlayerController`) per video URL**. The receiver bubble adds two listeners
to that shared controller:

1. `_videoListener` — added in `initState`, **removed in `dispose`** ✓ (balanced).
2. `_watchListener` — added in `_watchEndedFuture()` (the reaction watch-window,
   `receiver_message_widget.dart:~367`) via `controller.addListener(listener)`.
   It was **only** removed *inside itself*, when the video ends or pauses:
   ```dart
   if (ended || paused) {
     _watchEnded.complete();
     if (_watchListener != null) c.removeListener(_watchListener!);
   }
   ```
   `dispose()` completed `_watchEnded` and removed `_videoListener`, but **did
   not remove `_watchListener`.**

**The leak:** if the widget is disposed while the video is still *playing*
(scrolling away before it ends), the `if (ended || paused)` branch never runs,
so `_watchListener` is left attached to the **shared, cached** controller. Its
closure captures the widget's `_watchEnded`/`_watchListener` fields, so the
**disposed State can never be garbage-collected**.

**Why it matches the symptom:**

- Every reaction/video you open attaches one more orphaned `_watchListener` to a
  cached controller and pins one more dead widget State.
- Over ~a minute of viewing/scrolling reactions, dozens of dead States + their
  retained objects accumulate → **memory pressure**.
- On iOS, memory pressure makes the OS **reclaim video decode resources first** →
  in-flight players stop getting frames → **every video freezes at once**.
- It's independent of the *count* of live players (why capping the cache to 6
  didn't help): the leak is orphaned **listeners/State**, not player count.

This is also the most likely explanation for the earlier "reaction videos black"
report — same mechanism, not the P5/P6 media batch that was (unnecessarily, in
hindsight) reverted for it.

## The fix

`dispose()` now removes `_watchListener` from the shared controller and nulls it,
right after completing `_watchEnded`:

```dart
final controller = _flickManager?.flickVideoManager?.videoPlayerController;
controller?.removeListener(_videoListener);
final watchListener = _watchListener;
if (watchListener != null) {
  controller?.removeListener(watchListener);
  _watchListener = null;
}
```

Safe for the patent flow: `dispose` already completes `_watchEnded` (the watch
ends because the viewer left), so the reaction recorder stops as before; we're
only cleaning up the now-defunct listener. The patent-flow harness stays green.

## Honesty about certainty + how we confirm on-device

This is a **confirmed real bug** (read directly in the code) that matches the
symptom, and I fixed it. But I've mis-diagnosed this twice, so I won't claim
certainty it's the *sole* cause until it's confirmed on your device. If the
freeze persists after this build, the definitive next step is **on-device
diagnostic logging** (it cannot be reproduced headlessly):

1. In `dispose()`: log when disposing with a still-active `_watchListener`
   (counts real leaks).
2. In `VideoControllerCache.getFlickManager` / `pauseAllOtherVideos`: log cache
   size and call frequency.
3. Reproduce (view ~50–100 reactions over 1–2 min, then play one). If the leak
   warning fires many times and memory climbs, the diagnosis is confirmed; if
   not, we pivot to the next hypothesis (network buffering on large un-compressed
   older videos, or the per-frame `pauseAllOtherVideos` CPU cost).

## Secondary inefficiency (noted, not yet changed)

`_videoListener` calls `pauseAllOtherVideos()` on **every** position update
(~30–60×/s), and that iterates every cached controller. It's wasteful CPU but
constant (not accumulating), so it's not the freeze — worth optimising later to
fire only on an is-playing transition.

## Testability note

The video path goes through `VideoPlayerController.networkUrl`, which needs the
`video_player` platform channel, so this listener cleanup isn't unit-testable
without a mocking layer the app deliberately doesn't have. The patent-flow
harness exercises the widget's dispose path; the invariant is documented in a
code comment at the fix site.
