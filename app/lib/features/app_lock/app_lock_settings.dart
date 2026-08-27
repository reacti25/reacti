import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';

/// How long Reacti may sit in the background before it locks again.
///
/// A lock that re-prompts on every app switch is unusable — pick a photo to
/// send, come back, scan your face — and a feature people switch off protects
/// nobody. The grace period is what makes it liveable, so [immediately] is
/// offered but is deliberately not the default.
///
/// Mirrors the choices WhatsApp offers, which people already recognise.
enum AppLockDelay {
  /// Lock every time the app is foregrounded.
  immediately(Duration.zero, 'Immediately'),

  /// Lock after a minute away. The default.
  oneMinute(Duration(minutes: 1), 'After 1 minute'),

  /// Lock after fifteen minutes away.
  fifteenMinutes(Duration(minutes: 15), 'After 15 minutes');

  const AppLockDelay(this.duration, this.label);

  /// How long the app may stay backgrounded before locking.
  final Duration duration;

  /// The wording shown in the setting.
  final String label;

  /// The delay stored under [name], or [oneMinute] when absent or unreadable.
  ///
  /// Falls back rather than throwing: a stored value from a future build, or a
  /// renamed enum, must not leave someone unable to open the app.
  static AppLockDelay fromName(String? name) => AppLockDelay.values.firstWhere(
    (d) => d.name == name,
    orElse: () => AppLockDelay.oneMinute,
  );
}

/// Whether the app should be locked right now.
///
/// [lastBackgrounded] is when the app last went to the background, or null when
/// it has not since launch — a cold start always locks, because the app was not
/// merely away, it was gone.
///
/// Pure so every timing, and the awkward clocks, are testable without a device:
/// a phone whose clock jumps **backwards** (a timezone edit, an NTP
/// correction) would otherwise produce a negative gap and silently skip the
/// lock, which is the one direction this must never fail in.
bool shouldLock({
  required bool enabled,
  required AppLockDelay delay,
  required DateTime? lastBackgrounded,
  required DateTime now,
}) {
  if (!enabled) return false;
  if (lastBackgrounded == null) return true;

  final away = now.difference(lastBackgrounded);
  // A clock that moved backwards is not evidence the user was here. Lock.
  if (away.isNegative) return true;

  return away >= delay.duration;
}

/// Reads and writes the App Lock preferences.
///
/// Thin by design: the setting is two values in GetStorage, and the lock is
/// layered *above* the session — nothing here touches the auth token, so being
/// locked out is never being logged out.
class AppLockSettings {
  const AppLockSettings._();

  /// Whether the user has turned App Lock on. Defaults to false.
  static bool get enabled => appData.read(kKeyAppLockEnabled) == true;

  /// Records whether App Lock is on.
  static Future<void> setEnabled(bool value) =>
      appData.write(kKeyAppLockEnabled, value);

  /// The chosen delay, defaulting to [AppLockDelay.oneMinute].
  static AppLockDelay get delay =>
      AppLockDelay.fromName(appData.read(kKeyAppLockDelay) as String?);

  /// Records the chosen delay.
  static Future<void> setDelay(AppLockDelay value) =>
      appData.write(kKeyAppLockDelay, value.name);
}
