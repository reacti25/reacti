import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/theme/appearance_options.dart';
import 'package:reacti_app/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Lets the user pick the app's appearance: System, Light or Dark.
///
/// Mirrors WhatsApp's Theme setting. The choice is held and persisted by
/// [ThemeController] (via [AppearanceOptions]); selecting an option applies it
/// app-wide instantly and survives restarts. Also offered once at first run.
class AppearanceSettingsScreen extends StatelessWidget {
  /// Creates the appearance settings screen.
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appearance',
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: const AppearanceOptions(),
      ),
    );
  }
}
