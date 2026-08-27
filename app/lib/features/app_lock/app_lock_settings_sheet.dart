import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:reacti_app/features/app_lock/app_lock_settings.dart';
import 'package:reacti_app/features/app_lock/biometric_auth.dart';
import 'package:reacti_app/theme/app_theme.dart';

/// Opens the App Lock settings sheet.
Future<void> showAppLockSettings(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const AppLockSettingsSheet(),
);

/// The App Lock setting: on/off, and how long a trip away is allowed.
///
/// Off unless the user turns it on. Nobody is opted in to something that can
/// stand between them and their own messages.
class AppLockSettingsSheet extends StatefulWidget {
  /// Creates the settings sheet.
  const AppLockSettingsSheet({super.key});

  @override
  State<AppLockSettingsSheet> createState() => _AppLockSettingsSheetState();
}

class _AppLockSettingsSheetState extends State<AppLockSettingsSheet> {
  late bool _enabled = AppLockSettings.enabled;
  late AppLockDelay _delay = AppLockSettings.delay;

  /// Null until the device has been asked whether it can lock at all.
  bool? _supported;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final ok = await BiometricAuth.instance.isAvailable;
    if (!mounted) return;
    setState(() => _supported = ok);
  }

  /// Turns the lock on or off, proving identity in both directions.
  ///
  /// Turning it ON asks first, so nobody enables a lock their face or passcode
  /// cannot actually open — the moment to discover that is now, not next
  /// launch. Turning it OFF asks too, because a lock anyone holding the phone
  /// can switch off is decoration.
  Future<void> _toggle(bool value) async {
    final ok = await BiometricAuth.instance.authenticate(
      reason: value ? 'Turn on App Lock' : 'Turn off App Lock',
    );
    if (!mounted || !ok) return;

    await AppLockSettings.setEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  Future<void> _selectDelay(AppLockDelay value) async {
    await AppLockSettings.setDelay(value);
    if (!mounted) return;
    setState(() => _delay = value);
  }

  @override
  Widget build(BuildContext context) {
    final reacti = context.reacti;
    // Material, not a decorated Container: the switch and radio tiles paint
    // their background and ink on the nearest Material ancestor, and a
    // BoxDecoration between them and one hides those effects entirely.
    return Material(
      color: reacti.card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 22.h),
                    decoration: BoxDecoration(
                      color: reacti.hairline,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text(
                  'App Lock',
                  style: TextStyle(
                    color: reacti.textPrimary,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Ask for Face ID before opening Reacti, so the reactions your '
                  'friends sent you stay private if someone else picks up your '
                  'phone.',
                  style: TextStyle(
                    color: reacti.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                if (_supported == false)
                  Text(
                    "This phone has no Face ID, Touch ID or passcode set up, so "
                    'there is nothing for Reacti to lock with. Add a passcode in '
                    'iOS Settings to use App Lock.',
                    style: TextStyle(
                      color: reacti.textSecondary,
                      fontSize: 14.sp,
                    ),
                  )
                else
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    // Disabled until the device has answered, so nobody can flip
                    // a switch whose outcome is not yet known.
                    onChanged: _supported == null ? null : _toggle,
                    title: Text(
                      'Require Face ID',
                      style: TextStyle(
                        color: reacti.textPrimary,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                if (_enabled && _supported == true) ...[
                  SizedBox(height: 8.h),
                  Text(
                    'Lock when away for',
                    style: TextStyle(
                      color: reacti.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                  // RadioGroup rather than per-tile groupValue/onChanged, both
                  // deprecated after Flutter 3.32.
                  RadioGroup<AppLockDelay>(
                    groupValue: _delay,
                    onChanged: (v) {
                      if (v != null) _selectDelay(v);
                    },
                    child: Column(
                      children: [
                        for (final option in AppLockDelay.values)
                          RadioListTile<AppLockDelay>(
                            contentPadding: EdgeInsets.zero,
                            value: option,
                            title: Text(
                              option.label,
                              style: TextStyle(
                                color: reacti.textPrimary,
                                fontSize: 15.sp,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "If Face ID doesn't recognise you, your phone's passcode "
                    'always works.',
                    style: TextStyle(
                      color: reacti.textSecondary,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
