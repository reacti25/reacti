/// Placeholder legal/disclosure copy for the DG1 silent-recording consent flow.
///
/// Engineering builds the *mechanism*; the real consent/disclosure wording is
/// the lawyer's and is a **release gate**. Shipping with [kConsentCopyPlaceholder]
/// still present anywhere is the signal that the copy has not been replaced.
///
/// These strings are referenced by the registration consent screen
/// (`RecordingConsentScreen`) and the capture-point consent gate
/// (`ensureRecordingConsentAndPermission`).
library;

/// Marker string standing in for the lawyer's consent/disclosure copy.
const String kConsentCopyPlaceholder = '[[CONSENT_COPY_PENDING_LAWYER]]';

/// Human-readable placeholder describing the reaction-recording feature, shown
/// alongside [kConsentCopyPlaceholder] until the final wording lands.
const String kConsentFeatureBlurb =
    'Reacti can silently record a short reaction from your front camera when '
    'you open a media message, and share it back with the sender. '
    '(Placeholder copy — final wording pending legal review.)';
