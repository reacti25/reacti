import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../common_widget/custom_button.dart';
import '../../../constants/text_font_style.dart';
import '../../../helpers/all_routes.dart';
import '../../../helpers/di.dart';
import '../../../helpers/navigation_service.dart';
import '../../../helpers/ui_helpers.dart';
import '../data/consent_service.dart';

/// Placeholder marker for the legal disclosure/consent copy (DG1).
///
/// Engineering builds the *mechanism*; the real consent wording is the
/// lawyer's and is a release gate. Shipping with this marker still present is
/// the signal that the copy has not yet been replaced.
const String kConsentCopyPlaceholder = '[[CONSENT_COPY_PENDING_LAWYER]]';

/// One-time silent-recording consent shown once during registration (DG1 F2).
///
/// Presented after OTP verification, before the user reaches the app. It
/// discloses the patented silent reaction-recording feature and asks the user
/// to consent:
///
/// - **Accept** records consent on the server via [ConsentService.grantConsent]
///   (mirrored locally), then enters the app.
/// - **Decline** enters the app without consent; the reaction feature stays
///   off until the user consents at the capture point (DG1 F3).
///
/// Both paths land on [Routes.navigationScreen] and clear the auth stack so the
/// user cannot navigate back into the registration flow. The disclosure copy is
/// a [kConsentCopyPlaceholder]; the real wording is a release gate.
class RecordingConsentScreen extends StatefulWidget {
  /// Creates the registration-time recording-consent screen.
  const RecordingConsentScreen({super.key});

  @override
  State<RecordingConsentScreen> createState() => _RecordingConsentScreenState();
}

/// State for [RecordingConsentScreen]; owns the in-flight grant flag and the
/// resolved [ConsentService].
class _RecordingConsentScreenState extends State<RecordingConsentScreen> {
  /// Consent state owner (server-recorded, locally mirrored).
  final ConsentService _consent = locator<ConsentService>();

  /// Whether a [ConsentService.grantConsent] call is in flight; disables the
  /// buttons so the server POST is not fired twice by a double-tap.
  bool _submitting = false;

  /// Records consent on the server, then enters the app.
  ///
  /// Proceeds to the app regardless of the grant result: a transient failure
  /// must not trap the user on this screen — the capture-point gate (DG1 F3)
  /// re-prompts if consent did not actually persist.
  Future<void> _onAccept() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await _consent.grantConsent();
    _enterApp();
  }

  /// Enters the app without consent; the reaction feature stays off.
  void _onDecline() {
    if (_submitting) return;
    _enterApp();
  }

  /// Replaces the auth stack with the main navigation screen.
  void _enterApp() =>
      NavigationService.navigateToReplacementUntil(Routes.navigationScreen);

  /// Builds the disclosure body and the Accept / Decline actions.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Reaction Recording',
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UIHelper.verticalSpace(8.h),
                      Text(
                        'Before you continue',
                        style: TextFontStyle.headline18w400CFFFFFFPoppins,
                      ),
                      UIHelper.verticalSpace(16.h),
                      // Placeholder disclosure. The real consent/disclosure
                      // wording comes from Achia's lawyer and replaces this
                      // before release — see [kConsentCopyPlaceholder].
                      Text(
                        kConsentCopyPlaceholder,
                        style: TextFontStyle.headline14w400CCCCCCCPoppins,
                      ),
                      UIHelper.verticalSpace(12.h),
                      Text(
                        'Reacti can silently record a short reaction from your '
                        'front camera when you open a media message, and share '
                        'it back with the sender. You can decline now and turn '
                        'it on later. (Placeholder copy — final wording pending '
                        'legal review.)',
                        style: TextFontStyle.headline14w400CCCCCCCPoppins,
                      ),
                    ],
                  ),
                ),
              ),
              UIHelper.verticalSpace(16.h),
              CustomButton(
                key: const Key('consent_accept_button'),
                onTap: _submitting ? () {} : _onAccept,
                btnName: 'I agree',
              ),
              UIHelper.verticalSpace(12.h),
              TextButton(
                key: const Key('consent_decline_button'),
                onPressed: _submitting ? null : _onDecline,
                child: Text(
                  'Not now',
                  style: TextFontStyle.headline14w500CFFFFFFPoppins,
                ),
              ),
              UIHelper.verticalSpace(8.h),
            ],
          ),
        ),
      ),
    );
  }
}
