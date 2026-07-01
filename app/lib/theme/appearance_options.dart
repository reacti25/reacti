import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

/// The System / Light / Dark chooser rows, bound to [ThemeController].
///
/// Shared by the first-run appearance step and the Appearance settings screen
/// so the two can't drift. Tapping a row applies and persists the choice
/// instantly via [ThemeController.setThemeMode]; the active row shows a check.
class AppearanceOptions extends StatelessWidget {
  /// Creates the appearance chooser.
  const AppearanceOptions({super.key});

  /// The selectable modes, in display order, with their labels.
  static const _options = <(ThemeMode, String)>[
    (ThemeMode.system, 'System default'),
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
    );
  }
}
