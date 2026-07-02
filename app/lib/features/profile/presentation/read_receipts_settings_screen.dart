import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/profile/data/read_receipts_api.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Lets the user turn the reciprocal "Read receipts" preference on or off.
///
/// ON (the default) = the user sends "seen" signals and sees them from others;
/// OFF = neither, like WhatsApp. The choice is persisted server-side (so the
/// backend can withhold the user's outgoing seen broadcast) and mirrored into
/// local storage so chat bubbles can gate "seen" rendering synchronously.
class ReadReceiptsSettingsScreen extends StatefulWidget {
  /// Creates the read-receipts settings screen.
  const ReadReceiptsSettingsScreen({super.key});

  @override
  State<ReadReceiptsSettingsScreen> createState() =>
      _ReadReceiptsSettingsScreenState();
}

/// State for [ReadReceiptsSettingsScreen]; mirrors the stored preference and
/// persists changes, reverting on failure.
class _ReadReceiptsSettingsScreenState
    extends State<ReadReceiptsSettingsScreen> {
  /// Current toggle value; seeded from the mirrored preference (default on).
  late bool _enabled = _readStored();

  /// Whether a save is in flight (disables the switch to avoid double taps).
  bool _saving = false;

  /// Reads the locally mirrored preference, defaulting to on.
  bool _readStored() {
    final v = appData.read(kKeyReadReceipts);
    return v is bool ? v : true;
  }

  /// Persists the new [value], reverting and warning if the server rejects it.
  Future<void> _onChanged(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _saving = true;
    });
    // Mirror immediately so chat rendering reflects the choice without a fetch.
    appData.write(kKeyReadReceipts, value);
    try {
      await ReadReceiptsApi.instance.update(value);
    } catch (_) {
      // Revert on failure so the UI never claims a state the server rejected.
      appData.write(kKeyReadReceipts, previous);
      if (mounted) setState(() => _enabled = previous);
      ToastUtil.showErrorMessage("Couldn't update read receipts. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Read Receipts',
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: scheme.onSurface,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: SwitchListTile(
          key: const Key('read_receipts_switch'),
          value: _enabled,
          onChanged: _saving ? null : _onChanged,
          contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
          title: Text(
            'Read receipts',
            style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
              color: scheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              "When off, you won't send read receipts — and you won't see when "
              'others read your messages either.',
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
