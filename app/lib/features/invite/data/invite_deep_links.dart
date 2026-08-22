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
    final match = RegExp(r'/i/([A-Za-z0-9]+)').firstMatch(uri.path);
    if (match == null) return;
    final code = match.group(1)!;
    _pushConnect(code);
  }

  /// Pushes the connect screen once the navigator is ready (retries across
  /// frames for the cold-start case where the link arrives before first build).
  static void _pushConnect(String code) {
    final nav = NavigationService.navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pushConnect(code));
      return;
    }
    nav.push(
      MaterialPageRoute(builder: (_) => ConnectInviterScreen(code: code)),
    );
  }
}
