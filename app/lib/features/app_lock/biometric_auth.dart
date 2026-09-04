import 'dart:developer';

import 'package:local_auth/local_auth.dart';

/// Thin seam over `local_auth`, so the lock is testable without a device.
///
/// The plugin talks to a platform channel that does not exist under
/// `flutter test`, and the prompt itself can only be judged by a person looking
/// at a phone. Keeping the call behind one swappable object means everything
/// *around* it — when to lock, what the locked screen shows, whether the
/// setting can be turned off — is testable, which is where the bugs that lock
/// someone out of their account would live.
class BiometricAuth {
  /// Creates an authenticator over [auth], defaulting to the real plugin.
  BiometricAuth({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// Process-wide instance; mutable so a test can substitute a fake.
  static BiometricAuth instance = BiometricAuth();

  final LocalAuthentication _auth;

  /// Whether this device can lock the app at all.
  ///
  /// True when the device has biometrics OR a passcode, because the passcode is
  /// the fallback the whole design leans on. A device with neither cannot offer
  /// App Lock, and the setting must be hidden rather than shown broken.
  Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      // A plugin that throws here means no lock is possible. Say so rather
      // than letting the exception decide.
      log('App Lock: isDeviceSupported failed: $e');
      return false;
    }
  }

  /// Prompts for Face ID / Touch ID, falling back to the device passcode.
  ///
  /// Returns true only on a positive identification.
  ///
  /// `biometricOnly: false` is the important argument and not a default worth
  /// changing: Face ID fails constantly in real life — a mask, a dark room,
  /// sunglasses, a phone with no Face ID at all — and without the passcode
  /// route a bad scan would lock someone out of their own account with no way
  /// back but deleting the app.
  ///
  /// `persistAcrossBackgrounding: true` survives the app being backgrounded
  /// mid-prompt (an incoming call), which would otherwise come back as a
  /// failure. It is `stickyAuth` under the older name — local_auth 3.x
  /// flattened `AuthenticationOptions` into named arguments.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      // Cancelled, too many attempts, or biometrics changed on the device.
      // Failing closed keeps the app locked and the Unlock button available —
      // failing open would make the lock decorative.
      log('App Lock: authenticate failed: $e');
      return false;
    }
  }
}
