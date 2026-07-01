import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

/// Lets the user pick the app's appearance: System, Light or Dark.
///
/// Mirrors WhatsApp's Theme setting. The choice is held and persisted by
/// [ThemeController]; selecting an option applies it app-wide instantly and
/// survives restarts.
class AppearanceSettingsScreen extends StatelessWidget {
  /// Creates the appearance settings screen.
  const AppearanceSettingsScreen({super.key});

  /// The selectable options, in display order, with their labels.
  static const _options = <(ThemeMode, String)>[
    (ThemeMode.system, 'System default'),
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appearance',
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (mode, label) in _options)
              ListTile(
                key: Key('theme_mode_${mode.name}'),
                onTap: () => controller.setThemeMode(mode),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                title: Text(
                  label,
                  style: TextFontStyle.headline16w400CFFFFFFPoppins,
                ),
                trailing:
                    controller.themeMode == mode
                        ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                        : null,
              ),
          ],
        ),
      ),
    );
  }
}
