import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:reacti_app/features/app_lock/app_lock_settings.dart';
import 'package:reacti_app/features/app_lock/biometric_auth.dart';
import 'package:reacti_app/theme/app_theme.dart';

/// Wraps the app and covers it whenever App Lock says it should be locked.
///
/// Sits **above** the session: it never touches the auth token, so failing to
/// unlock is never being logged out. That matters more than it sounds — the
/// worst outcome this feature can produce is taking someone's account away from
/// them, and keeping the two layers separate is what makes that impossible.
///
/// Does nothing at all unless the user turned the setting on.
class AppLockGate extends StatefulWidget {
  /// Wraps [child] — the whole app — in the lock.
  const AppLockGate({required this.child, super.key});

  /// The app being protected.
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  /// Whether the cover is up right now.
  bool _locked = false;

  /// Guards against two prompts at once — the lifecycle can fire more than
  /// once around a single foregrounding, and iOS shows one prompt per app.
  bool _prompting = false;

  /// When the app last went to the background, or null if it has not since
  /// launch.
  DateTime? _lastBackgrounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A cold start counts as "was away": the app was not backgrounded, it was
    // gone, and that is exactly when someone else might be holding the phone.
    _locked = AppLockSettings.enabled;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptUnlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ONLY `paused` counts as leaving. `inactive` fires constantly while the
    // app is still open and in front of you — Control Centre pulled down, a
    // notification banner, the incoming-call bar, the app switcher preview, and
    // any system dialog including the Face ID prompt this feature raises. On
    // "Immediately" (delay zero) treating those as a trip away locked the app
    // while the user was sitting in it, and could even re-lock straight after
    // an unlock. `paused` is the state that means genuinely backgrounded, and
    // it always follows `inactive` on a real trip away, so nothing is missed.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Stamped on the way out, not read on the way in, so a phone that never
      // comes back still has a timestamp when it eventually does.
      _lastBackgrounded ??= DateTime.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final away = _lastBackgrounded;
    _lastBackgrounded = null;
    if (_locked) return;

    // No stamp means the app never actually went to the background, so this
    // resume is the tail of something transient. A cold start is handled in
    // initState, where a null stamp DOES mean locked — here it means the
    // opposite, and reading it the initState way locked the app while the user
    // was still in it.
    if (away == null) return;

    final lock = shouldLock(
      enabled: AppLockSettings.enabled,
      delay: AppLockSettings.delay,
      lastBackgrounded: away,
      now: DateTime.now(),
    );
    if (!lock) return;

    setState(() => _locked = true);
    _promptUnlock();
  }

  /// Asks for Face ID / passcode and lifts the cover on success.
  Future<void> _promptUnlock() async {
    if (_prompting) return;
    _prompting = true;
    try {
      final ok = await BiometricAuth.instance.authenticate(
        reason: 'Unlock Reacti',
      );
      if (!mounted || !ok) return;
      setState(() => _locked = false);
    } finally {
      _prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // A full cover, not a dialog: a dialog leaves the last thread visible
        // behind it, and the app switcher screenshots whatever is on screen.
        if (_locked) const Positioned.fill(child: _LockCover()),
      ],
    );
  }
}

/// The opaque screen shown while the app is locked.
///
/// Carries an Unlock button because a dismissed or failed prompt must be
/// recoverable — without it, one cancelled scan would leave a permanently
/// blank app and no way forward.
class _LockCover extends StatelessWidget {
  const _LockCover();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AppLockGateState>();
    return Material(
      color: context.reacti.canvas,
      // Scrollable and shrink-wrapped: at large accessibility text sizes the
      // icon, heading and button together outgrow a short screen, and a lock
      // screen whose Unlock button has overflowed off the bottom is an
      // unopenable app.
      child: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56.r,
                color: context.reacti.textSecondary,
              ),
              SizedBox(height: 16.h),
              Text(
                'Reacti is locked',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: context.reacti.textPrimary,
                ),
              ),
              SizedBox(height: 24.h),
              FilledButton(
                onPressed: () => state?._promptUnlock(),
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
