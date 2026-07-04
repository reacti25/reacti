import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/theme/appearance_options.dart';
import 'package:reacti_app/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

/// Whether to offer the one-time first-run appearance picker now.
///
/// Only after a fresh sign-up ([kKeyJustSignedUp]) and only until the user has
/// been asked once ([kKeyAppearanceAsked]) — so returning logins and repeat
/// launches never see it.
bool shouldPromptAppearance(GetStorage store) =>
    store.read(kKeyJustSignedUp) == true &&
    store.read(kKeyAppearanceAsked) != true;

/// Shows the first-run appearance picker (System / Light / Dark) as a modal
/// dialog, then records that the prompt has been shown so it never reappears.
///
/// Reuses [AppearanceOptions], which applies each choice live. "Use this" keeps
/// the tapped choice; "Skip" reverts to following the system (the default).
Future<void> showAppearancePickerDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AppearancePickerDialog(),
  );
  await appData.write(kKeyAppearanceAsked, true);
}

/// The dialog body: a short prompt, the live System/Light/Dark selector, and
/// Skip / Use-this actions.
class _AppearancePickerDialog extends StatelessWidget {
  const _AppearancePickerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose your appearance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick a look for the app. You can change this anytime in Settings.',
          ),
          SizedBox(height: 8.h),
          const AppearanceOptions(),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('appearance_skip'),
          onPressed: () {
            // Skip → follow the system appearance (the default).
            context.read<ThemeController>().setThemeMode(ThemeMode.system);
            Navigator.of(context).pop();
          },
          child: const Text('Skip'),
        ),
        TextButton(
          key: const Key('appearance_use_this'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Use this'),
        ),
      ],
    );
  }
}
