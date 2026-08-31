/// Measures how long people actually spend in the app.
///
/// `session_start` was declared in the catalog from the beginning but never
/// emitted, so session length has never been answerable. This fires it on
/// launch and on every return to the foreground, and pairs it with
/// `session_end` carrying the elapsed time.
///
/// Session length is the difference between "they opened it" and "they used
/// it", which retention alone cannot tell apart: someone opening the app daily
/// for four seconds is not a retained user in any sense that matters.
library;

import 'package:flutter/widgets.dart';

import 'analytics_locator.dart';
import 'events.dart';

/// Starts and ends analytics sessions from the app's lifecycle.
///
/// Install once during bootstrap with [start]. Fire-and-forget throughout:
/// nothing here can throw into the lifecycle callback.
class SessionTracker with WidgetsBindingObserver {
  /// Time the current foreground session began, or null between sessions.
  Stopwatch? _open;

  /// Installs the observer and opens the first session.
  ///
  /// Returns the instance so a test can [dispose] it; the app ignores it.
  static SessionTracker start() {
    final tracker = SessionTracker();
    WidgetsBinding.instance.addObserver(tracker);
    tracker._begin();
    return tracker;
  }

  /// Opens a session and emits `session_start`.
  void _begin() {
    _open = Stopwatch()..start();
    try {
      analytics.track(Events.sessionStart);
    } catch (_) {
      // Fire-and-forget.
    }
  }

  /// Closes the open session and emits `session_end` with its length.
  ///
  /// A no-op when no session is open, so a duplicate `paused` cannot emit a
  /// second `session_end` and halve the median.
  void _end() {
    final open = _open;
    if (open == null) return;
    _open = null;
    try {
      analytics.track(Events.sessionEnd, {
        Props.elapsedMs: open.elapsedMilliseconds,
      });
    } catch (_) {
      // Fire-and-forget.
    }
  }

  /// Ends the session when the app leaves the foreground, starts one when it
  /// comes back.
  ///
  /// Only `paused` counts as leaving. `inactive` fires while the app is still
  /// on screen (a system dialog, the app switcher, a permission prompt), and
  /// treating it as an exit would chop one real session into several short
  /// ones and drag the median down.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _end();
    } else if (state == AppLifecycleState.resumed && _open == null) {
      _begin();
    }
  }

  /// Removes the observer. For tests, and for symmetry.
  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
