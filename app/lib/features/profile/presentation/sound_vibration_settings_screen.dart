import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Lets the user turn the in-app "Sound & vibration" feedback on or off.
///
/// ON (the default) = a light sound + vibration when you send and receive
/// messages; OFF = silent. The choice is local-only (no server), mirrored into
/// GetStorage and pushed live into [FeedbackService].
class SoundVibrationSettingsScreen extends StatefulWidget {
  /// Creates the sound & vibration settings screen.
  const SoundVibrationSettingsScreen({super.key});

  @override
  State<SoundVibrationSettingsScreen> createState() =>
      _SoundVibrationSettingsScreenState();
}

/// State for [SoundVibrationSettingsScreen]; mirrors and persists the toggle.
class _SoundVibrationSettingsScreenState
    extends State<SoundVibrationSettingsScreen> {
  /// Current toggle value; seeded from the stored preference (default on).
  late bool _enabled = _readStored();

  /// Reads the stored preference, defaulting to on. Guarded so it still builds
  /// if storage isn't ready (e.g. in a widget test).
  bool _readStored() {
    try {
      return appData.read(kKeySoundHapticsEnabled) != false;
    } catch (_) {
      return true;
    }
  }

  /// Persists the new [value] locally and applies it immediately.
  void _onChanged(bool value) {
    setState(() => _enabled = value);
    appData.write(kKeySoundHapticsEnabled, value);
    FeedbackService.setEnabled(value);
    // Give an immediate taste of the feedback when turning it on.
    if (value) FeedbackService.messageSent();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sound & Vibration',
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: scheme.onSurface,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: SwitchListTile(
          key: const Key('sound_vibration_switch'),
          value: _enabled,
          onChanged: _onChanged,
          contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
          title: Text(
            'Sound & vibration',
            style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
              color: scheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              'Play a sound and vibrate when you send and receive messages.',
              style: TextFontStyle.headline14w400CCCCCCCPoppins.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
