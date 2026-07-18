import 'package:no_screenshot/no_screenshot.dart';

/// Blocks and re-allows screen capture around sensitive UI — the view-once
/// full-screen viewer.
///
/// Exposed as a swappable seam (like `reactionRecorder` and
/// `videoSendCompressor`) so a widget test can assert that protection was
/// turned on while the viewer was open and off when it closed, without
/// invoking the native plugin.
///
/// The honest ceiling (see docs/PLAN-view-once-media-2026-07-18.md §6): on
/// Android this is a hard block of screenshots and recording; on iOS it blanks
/// the content out of a capture but cannot stop the gesture, and neither
/// platform defends against a second camera photographing the screen.
abstract class ScreenshotGuard {
  /// Blocks capture. Android sets `FLAG_SECURE`; iOS blanks the protected
  /// content in screenshots and recordings.
  Future<void> block();

  /// Re-allows capture. Call when the sensitive screen closes so the rest of
  /// the app is unaffected.
  Future<void> allow();
}

/// Real guard backed by the `no_screenshot` plugin.
class RealScreenshotGuard implements ScreenshotGuard {
  @override
  Future<void> block() async {
    await NoScreenshot.instance.screenshotOff();
  }

  @override
  Future<void> allow() async {
    await NoScreenshot.instance.screenshotOn();
  }
}

/// Swappable guard instance; tests replace it with a fake. Mirrors the
/// `reactionRecorder` global-seam pattern used elsewhere in chat.
ScreenshotGuard screenshotGuard = RealScreenshotGuard();
