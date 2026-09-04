import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../analytics/analytics_consent.dart';
import '../../../constants/text_font_style.dart';
import '../../../helpers/di.dart';

/// Lets the user opt out of (or back into) anonymous usage analytics.
///
/// The **only** user-facing addition the analytics plan permits. The switch is
/// "Share anonymous usage data": ON = opted in (the default), OFF = opted out.
/// Toggling persists the choice via [AnalyticsConsent] and applies it
/// immediately (no events are emitted while opted out). Observation-only — it
/// changes nothing else about the app.
class AnalyticsSettingsScreen extends StatefulWidget {
  /// Creates the analytics opt-out settings screen.
  const AnalyticsSettingsScreen({super.key});

  @override
  State<AnalyticsSettingsScreen> createState() =>
      _AnalyticsSettingsScreenState();
}

/// State for [AnalyticsSettingsScreen]; mirrors the stored opt-out preference.
class _AnalyticsSettingsScreenState extends State<AnalyticsSettingsScreen> {
  /// Owns the persisted opt-out flag.
  final AnalyticsConsent _consent = locator<AnalyticsConsent>();

  /// Whether sharing is enabled (i.e. NOT opted out).
  late bool _shareEnabled = !_consent.isOptedOut;

  /// Persists the new choice and applies it to the SDK.
  Future<void> _onChanged(bool value) async {
    setState(() => _shareEnabled = value);
    await _consent.setOptedOut(!value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Usage Data',
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: scheme.onSurface,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: SwitchListTile(
          key: const Key('analytics_optout_switch'),
          value: _shareEnabled,
          onChanged: _onChanged,
          contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
          title: Text(
            'Share anonymous usage data',
            style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
              color: scheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              'Helps us improve Reacti. Only anonymous, aggregated metadata is '
              'collected. Never your messages, media, camera, or identity. You '
              'can turn this off at any time.',
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
