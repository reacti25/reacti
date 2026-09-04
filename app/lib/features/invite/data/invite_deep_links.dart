import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:reacti_app/features/invite/presentation/connect_inviter_screen.dart';
import 'package:reacti_app/helpers/navigation_service.dart';

/// Handles incoming Universal Links for personal invites (Feature 5).
///
/// When the app is opened via a `https://…/i/{code}` link (tapped while
/// installed), this routes straight to the [ConnectInviterScreen] — no manual
/// paste needed. Backed by the AASA file the backend serves and the
/// `applinks:` entitlement on the app.
class InviteDeepLinks {
  InviteDeepLinks._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  /// The code currently being shown, so the same invite is never opened twice.
  ///
  /// Two things used to double up on it. `app_links` replays the cold-start
  /// link on [AppLinks.uriLinkStream] as well as returning it from
  /// [AppLinks.getInitialLink], and iOS re-delivers the link every time the app
  /// is foregrounded from the same page. Either way the user got connect
  /// screens stacked on top of each other.
  static String? _showing;

  /// How many frames [_pushConnect] waits for a navigator before giving up.
  ///
  /// The navigator normally arrives within a frame or two of the first build.
  /// The cap exists because the retry re-arms itself: without it a navigator
  /// that never appears means an unbounded chain of post-frame callbacks, and
  /// an app too busy to draw is an app iOS terminates.
  static const int _maxNavigatorWaitFrames = 120;

  /// Starts listening for invite links (cold-start + while-running). Safe to
  /// call once after the app boots.
  static Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      log('Deep link initial fetch failed: $e');
    }
    _sub ??= _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => log('Deep link stream error: $e'),
    );
  }

  /// Routes an `/i/{code}` link to the connect screen; ignores anything else.
  static void _handle(Uri uri) {
    final code = codeFrom(uri);
    if (code == null || code == _showing) return;
    _showing = code;
    _pushConnect(code);
  }

  /// The invite code in [uri], or null when it carries none.
  ///
  /// Pure so the matching is testable without the plugin or a navigator.
  static String? codeFrom(Uri uri) =>
      RegExp(r'/i/([A-Za-z0-9]+)').firstMatch(uri.path)?.group(1);

  /// Pushes the connect screen once the navigator is ready (retries across
  /// frames for the cold-start case where the link arrives before first build).
  static void _pushConnect(String code, [int attempt = 0]) {
    final nav = NavigationService.navigatorKey.currentState;
    if (nav == null) {
      if (attempt >= _maxNavigatorWaitFrames) {
        // Nothing to push onto. Release the code so a later tap still works
        // rather than being swallowed as a duplicate.
        log('Deep link: no navigator after $attempt frames; dropping $code');
        _showing = null;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pushConnect(code, attempt + 1),
      );
      return;
    }
    nav
        .push(
          MaterialPageRoute(builder: (_) => ConnectInviterScreen(code: code)),
        )
        // Cleared on close, so the same invite can be opened again on purpose
        // — only the automatic re-deliveries are swallowed.
        .whenComplete(() {
          if (_showing == code) _showing = null;
        });
  }

  /// Forgets the in-flight code. For tests, which have no navigator to pop.
  @visibleForTesting
  static void resetForTest() => _showing = null;
}
