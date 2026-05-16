import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

/// Static branding screen shown while [Loading] resolves the initial route.
///
/// Purely presentational — it performs no navigation or async work itself;
/// [Loading] swaps it out once startup data is ready.
class SplashScreen extends StatefulWidget {
  /// Creates the [SplashScreen] widget.
  const SplashScreen({super.key});

  /// Creates the mutable state for this widget.
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// [State] for [SplashScreen]; holds no mutable state and only builds the UI.
class _SplashScreenState extends State<SplashScreen> {
  /// Builds the centred app logo and tagline.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(Assets.icons.appLogo),
          UIHelper.verticalSpace(20.h),
          Center(
            child: Text(
              "Share moments. Capture real \nreactions.",
              style: TextFontStyle.headline18w400CFFFFFFPoppins,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
