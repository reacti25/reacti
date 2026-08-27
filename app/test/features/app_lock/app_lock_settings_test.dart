// App Lock: when to lock, and what the setting defaults to.
//
// The prompt itself is a platform channel and can only be judged by a person
// holding a phone. Everything around it is testable, and that is where the bug
// that matters would live — the worst thing this feature can do is take
// someone's account away from them, so the cases below lean on the side of
// locking, never on the side of letting someone in.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/app_lock/app_lock_settings.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../support/test_storage.dart';

void main() {
  setUp(() async {
    await initTestGetStorage();
    await appData.remove(kKeyAppLockEnabled);
    await appData.remove(kKeyAppLockDelay);
  });

  group('defaults', () {
    test('App Lock is OFF until asked for', () {
      // Nobody is opted in to something that can stand between them and their
      // own messages.
      expect(AppLockSettings.enabled, isFalse);
    });

    test('the delay defaults to one minute, not immediately', () {
      // Prompting on every app switch — pick a photo, come back, scan — is how
      // people end up turning the lock off entirely, which protects nobody.
      expect(AppLockSettings.delay, AppLockDelay.oneMinute);
    });

    test(
      'an unreadable stored delay falls back rather than throwing',
      () async {
        // A value from a future build, or a renamed enum. Throwing here would
        // leave someone unable to open the app.
        await appData.write(kKeyAppLockDelay, 'someDelayFromTheFuture');
        expect(AppLockSettings.delay, AppLockDelay.oneMinute);
      },
    );
  });

  group('shouldLock', () {
    final now = DateTime(2026, 8, 27, 12, 0);

    test('never locks while the setting is off', () {
      expect(
        shouldLock(
          enabled: false,
          delay: AppLockDelay.immediately,
          lastBackgrounded: now.subtract(const Duration(hours: 5)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a cold start locks', () {
      // No record of backgrounding means the app was not away, it was gone —
      // exactly when someone else might be holding the phone.
      expect(
        shouldLock(
          enabled: true,
          delay: AppLockDelay.fifteenMinutes,
          lastBackgrounded: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('a trip shorter than the delay does not lock', () {
      expect(
        shouldLock(
          enabled: true,
          delay: AppLockDelay.oneMinute,
          lastBackgrounded: now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        isFalse,
      );
    });

    test('exactly the delay locks', () {
      // The boundary belongs on the locking side.
      expect(
        shouldLock(
          enabled: true,
          delay: AppLockDelay.oneMinute,
          lastBackgrounded: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('immediately locks on any trip at all', () {
      expect(
        shouldLock(
          enabled: true,
          delay: AppLockDelay.immediately,
          lastBackgrounded: now.subtract(const Duration(milliseconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('fifteen minutes tolerates fourteen', () {
      expect(
        shouldLock(
          enabled: true,
          delay: AppLockDelay.fifteenMinutes,
          lastBackgrounded: now.subtract(const Duration(minutes: 14)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a clock that jumped BACKWARDS locks', () {
      // A timezone edit or an NTP correction makes the gap negative. Read
      // naively that is "no time passed", which would silently skip the lock —
      // the one direction this must never fail in.
      expect(
        shouldLock(
          enabled: true,
          delay: AppLockDelay.fifteenMinutes,
          lastBackgrounded: now.add(const Duration(hours: 2)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('persistence', () {
    test('the setting survives a write and read, as a launch would', () async {
      await AppLockSettings.setEnabled(true);
      await AppLockSettings.setDelay(AppLockDelay.fifteenMinutes);

      expect(AppLockSettings.enabled, isTrue);
      expect(AppLockSettings.delay, AppLockDelay.fifteenMinutes);
    });

    test('every delay round-trips through storage', () {
      for (final delay in AppLockDelay.values) {
        expect(AppLockDelay.fromName(delay.name), delay);
      }
    });
  });
}
