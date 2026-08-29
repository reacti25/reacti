// ignore_for_file: constant_identifier_names

/// Typed analytics event names and property keys, plus the **allowlist** that
/// the [AnalyticsService] enforces.
///
/// This is the code mirror of `docs/analytics/event-catalog.md`: every event and
/// every allowed property is a constant here, and [eventAllowlist] maps each
/// event to the feature properties it may carry. Feature code uses these
/// constants — never raw strings — so events stay consistent and the privacy
/// allowlist is enforceable.
///
/// To add an event: update the catalog doc and these constants together in the
/// same PR. The analytics tests fail the build if the two drift (an event with
/// no allowlist entry, or an allowlist key that is not a known [Props]).
library;

/// Canonical event names (the wire value sent to the analytics backend).
final class Events {
  Events._();

  // App lifecycle
  static const String appOpen = 'app_open';
  static const String screenView = 'screen_view';
  static const String sessionStart = 'session_start';

  // UI performance (timing metadata only)
  static const String screenRender = 'screen_render';
  static const String frameJank = 'frame_jank';

  // Messaging
  static const String messageSent = 'message_sent';
  static const String mediaUploaded = 'media_uploaded';

  /// On-send media compression (downscale/re-encode) that runs on the sender's
  /// device *before* the upload. Its cost is otherwise invisible — `send_ms` /
  /// `upload_ms` only cover the HTTP call — so it's the missing piece when the
  /// sender feels a delay between hitting send and the upload starting.
  static const String mediaCompressed = 'media_compressed';
  static const String messageReceived = 'message_received';

  // Reaction / patent flow (metadata only — never the recorded media)
  static const String reactionRecorded = 'reaction_recorded';
  static const String reactionSent = 'reaction_sent';
  static const String reactionViewed = 'reaction_viewed';

  /// The loop closing for the first time: a reaction came back to something
  /// this user sent. The real aha — a Reacti is not a Reacti until a face
  /// returns — and so the truest activation marker in the app.
  static const String firstReactionReceived = 'first_reaction_received';
  static const String markViewedToReaction = 'mark_viewed_to_reaction';

  /// Outcome of the `mark-viewed` call that gates the reaction flow — emitted
  /// from the view-inbox/view-group rx layer so a failed mark-viewed (which
  /// silently aborts the flow) is observable.
  static const String markViewedResult = 'mark_viewed_result';

  /// The reaction send was skipped at an early-return (missing user/group/
  /// message id) after the media was opened — a wiring fault that would
  /// otherwise leave a viewed message with no reaction and no signal.
  static const String reactionSendSkipped = 'reaction_send_skipped';

  // Patent authenticity / media UX (timing metadata only — never the media)
  static const String mediaLoaded = 'media_loaded';
  static const String mediaExposure = 'media_exposure';
  static const String recordingMediaOverlap = 'recording_media_overlap';

  /// Per-segment timing of the open sequence (tap → mark-viewed → media-ready →
  /// painted → record-start), anchored at the tap (t=0). The Phase-0 baseline
  /// that proves the trigger-on-paint re-anchoring (see
  /// `docs/PLAN-media-timing-and-speed-2026-06-23.md`).
  static const String mediaTimeline = 'media_timeline';

  /// Seal integrity: did a received media message arrive sealed (blurred) or
  /// already-open? The core-feature KPI and the diagnostic for the
  /// "media arrives unsealed" investigation (Branch C).
  static const String mediaReceivedSealState = 'media_received_seal_state';

  // Growth & funnel
  static const String registerStarted = 'register_started';
  static const String otpVerified = 'otp_verified';

  /// A new account was created (OTP verified). The activation funnel's first
  /// step and the anchor for the north-star "first reaction within 24h" cohort.
  static const String signupCompleted = 'signup_completed';
  static const String firstMessageSent = 'first_message_sent';
  static const String consentDecision = 'consent_decision';

  // Engagement & social graph
  static const String groupCreated = 'group_created';
  static const String groupJoined = 'group_joined';
  static const String friendAdded = 'friend_added';

  // --- Invite loop (Feature 5) ---
  /// A contact was invited via the share sheet (share sheet was invoked).
  static const String inviteShared = 'invite_shared';

  /// The post-signup "Connect with {Inviter}" screen was shown.
  static const String inviteOpened = 'invite_opened';

  /// The invitee tapped Connect and the friendship was created.
  static const String inviteConnected = 'invite_connected';

  // --- Onboarding / activation (demo Reacti) ---
  /// The one-time practice Reacti was started (Step 1 CTA tapped).
  /// A walkthrough step was shown. `step` says which.
  ///
  /// The walkthrough has been built and rebuilt for weeks on judgement alone.
  /// One event per step is the standard onboarding shape, and the only way to
  /// see which step loses people rather than guessing.
  static const String walkthroughStepShown = 'walkthrough_step_shown';

  /// The walkthrough was replayed deliberately from Profile.
  ///
  /// Distinguishes "shown to a new user" from "asked for again", which are
  /// different behaviours that would otherwise sit in one number.
  static const String walkthroughReplayed = 'walkthrough_replayed';

  /// The demo screen was opened.
  ///
  /// Distinct from [demoStarted], which is the user tapping "Open demo
  /// Reacti". Without this, anyone who opens the demo and backs out is
  /// invisible, and that gap is exactly where a demo would be losing people.
  static const String demoOpened = 'demo_opened';

  static const String demoStarted = 'demo_started';

  /// The practice Reacti reached its reveal (Step 3) — the activation funnel's
  /// "Demo done" step. Never carries the captured media.
  static const String demoReactionCompleted = 'demo_reaction_completed';

  /// Every known event name — used by tests to assert allowlist completeness.
  static const Set<String> all = {
    appOpen,
    screenView,
    sessionStart,
    screenRender,
    frameJank,
    messageSent,
    mediaUploaded,
    mediaCompressed,
    messageReceived,
    reactionRecorded,
    reactionSent,
    reactionViewed,
    firstReactionReceived,
    markViewedToReaction,
    markViewedResult,
    reactionSendSkipped,
    mediaLoaded,
    mediaExposure,
    recordingMediaOverlap,
    mediaTimeline,
    mediaReceivedSealState,
    registerStarted,
    otpVerified,
    signupCompleted,
    firstMessageSent,
    consentDecision,
    groupCreated,
    groupJoined,
    friendAdded,
    walkthroughStepShown,
    walkthroughReplayed,
    demoOpened,
    demoStarted,
    demoReactionCompleted,
    inviteShared,
    inviteOpened,
    inviteConnected,
  };
}

/// Canonical property keys (allowlisted metadata only — never content/PII).
final class Props {
  Props._();

  // --- Global properties (attached to every event by the service) ---
  static const String distinctId = 'distinct_id';
  static const String analyticsEnv = 'analytics_env';
  static const String platform = 'platform';
  static const String appVersion = 'app_version';
  static const String appBuild = 'app_build';
  static const String sessionId = 'session_id';
  static const String ts = 'ts';

  // --- Per-event feature properties ---
  static const String messageType = 'message_type';
  static const String scope = 'scope';
  static const String sendMs = 'send_ms';
  static const String result = 'result';
  static const String hasReply = 'has_reply';
  static const String uploadMs = 'upload_ms';

  /// Milliseconds the on-send compression took on the sender's device (image
  /// downscale or video transcode) before the upload began.
  static const String compressMs = 'compress_ms';
  static const String sizeBucket = 'size_bucket';
  static const String network = 'network';
  static const String mediaKind = 'media_kind';
  static const String deliveryMs = 'delivery_ms';
  static const String coldStartMs = 'cold_start_ms';
  static const String isColdStart = 'is_cold_start';
  static const String screen = 'screen';
  static const String previousScreen = 'previous_screen';
  static const String recordMs = 'record_ms';
  static const String failureReason = 'failure_reason';

  /// What started the silent recording: `painted` / `timeout` (paint-anchored
  /// trigger) or `immediate` (flag off). Splits overlap by trigger on the
  /// dashboard and surfaces the timeout share.
  static const String recordTriggerReason = 'record_trigger_reason';

  /// Why a reaction send was skipped: `missing_user_id` | `missing_group_id` |
  /// `null_message_id`.
  static const String reason = 'reason';
  static const String elapsedMs = 'elapsed_ms';
  static const String method = 'method';
  static const String decision = 'decision';
  static const String memberCountBucket = 'member_count_bucket';
  static const String groupSizeBucket = 'group_size_bucket';

  // --- Patent authenticity / media UX timing (ms; metadata only) ---
  /// Unblur → media first painted/decoded (image decode or video first frame).
  static const String mediaLoadMs = 'media_load_ms';

  /// How long the viewed media was actually on screen (unblur → hidden).
  static const String mediaExposureMs = 'media_exposure_ms';

  /// Milliseconds the silent recording window overlapped the media-exposure
  /// window — the authenticity signal (reaction captured while media was shown).
  static const String overlapMs = 'overlap_ms';

  /// [overlapMs] as a percentage of [recordingDurationMs] (0–100, clamped).
  static const String overlapPct = 'overlap_pct';

  /// Signed offset of recording start relative to media becoming visible
  /// (negative = recording began before the media was on screen).
  static const String recordingStartOffsetMs = 'recording_start_offset_ms';

  /// Duration of the silent recording window.
  static const String recordingDurationMs = 'recording_duration_ms';

  // --- Tap-anchored open timeline (ms from tap; null until that segment
  // occurs). The baseline for the trigger-on-paint re-anchoring (Phase 1). ---
  /// tap → `mark-viewed` response (unblur).
  static const String markViewedMs = 'mark_viewed_ms';

  /// tap → media ready (image decoded / video first frame).
  static const String mediaReadyMs = 'media_ready_ms';

  /// tap → first painted frame after the media was ready (the moment the
  /// trigger re-anchor will fire on).
  static const String paintedMs = 'painted_ms';

  /// tap → silent recording start.
  static const String recordStartMs = 'record_start_ms';

  // --- UI performance ---
  /// Route push → first painted frame of the new screen (time-to-interactive).
  static const String screenRenderMs = 'screen_render_ms';

  /// Milliseconds from this install's FIRST LAUNCH to the event.
  ///
  /// Time-to-value, per funnel step. Absent when the install predates the
  /// first-launch stamp, rather than zero, which would read as an instant
  /// conversion that never happened.
  static const String msSinceFirstLaunch = 'ms_since_first_launch';

  /// Coarse country, from the device locale (e.g. `IL`, `US`).
  ///
  /// Region only, never a city and never coordinates. Enough to answer "where
  /// are our users" without narrowing anyone down.
  static const String country = 'country';

  /// Device language (e.g. `en`, `he`), for deciding what to translate.
  static const String language = 'language';

  /// Which walkthrough step an event refers to, e.g. `add_friend`.
  ///
  /// The step name, not an index: renumbering the walkthrough must not silently
  /// re-label months of history.
  static const String step = 'step';

  /// Number of janky frames (over the budget) in the reported window.
  static const String jankFrameCount = 'jank_frame_count';

  /// Arrival seal state of a received media message: `sealed` (would render the
  /// blur placeholder) | `open` (rendered unblurred — a bug when it shouldn't).
  static const String sealState = 'seal_state';

  /// Raw `media_type` string exactly as received from the API/broadcast (e.g.
  /// `image`, `video`, `image/jpeg`, or `(null)` when absent). Diagnostic only —
  /// reveals unexpected values that slip past the exact-string seal condition.
  static const String mediaTypeRaw = 'media_type_raw';

  /// Slowest single frame (ms) in the reported window.
  static const String jankMaxMs = 'jank_max_ms';

  /// Total frames observed in the reported window (denominator for jank rate).
  static const String frameCount = 'frame_count';

  /// The seven global property keys, always allowed on every event.
  static const Set<String> globals = {
    distinctId,
    analyticsEnv,
    platform,
    appVersion,
    appBuild,
    sessionId,
    ts,
    country,
    language,
  };
}

/// Per-event allowlist of **feature** property keys (globals are always allowed
/// and are added separately by the service). Any property a caller passes that
/// is not in this set for the given event is dropped before dispatch.
///
/// This map is the enforcement of `docs/analytics/event-catalog.md`. Events with
/// no feature props map to an empty set (globals only).
const Map<String, Set<String>> eventAllowlist = {
  Events.appOpen: {Props.coldStartMs, Props.isColdStart},
  Events.screenView: {Props.screen, Props.previousScreen},
  Events.sessionStart: {},
  Events.screenRender: {Props.screen, Props.screenRenderMs},
  Events.frameJank: {
    Props.screen,
    Props.jankFrameCount,
    Props.jankMaxMs,
    Props.frameCount,
  },
  Events.messageSent: {
    Props.messageType,
    Props.scope,
    Props.sendMs,
    Props.result,
    Props.hasReply,
    Props.failureReason,
  },
  Events.mediaUploaded: {
    Props.uploadMs,
    Props.sizeBucket,
    Props.network,
    Props.mediaKind,
    Props.result,
  },
  Events.mediaCompressed: {
    Props.compressMs,
    Props.mediaKind,
    Props.sizeBucket,
    Props.result,
  },
  Events.messageReceived: {Props.messageType, Props.scope, Props.deliveryMs},
  Events.reactionRecorded: {
    Props.scope,
    Props.recordMs,
    Props.recordTriggerReason,
    Props.result,
    Props.failureReason,
  },
  Events.reactionSent: {
    Props.scope,
    Props.uploadMs,
    Props.sizeBucket,
    Props.result,
    Props.failureReason,
  },
  Events.reactionViewed: {Props.scope},
  Events.markViewedToReaction: {Props.scope, Props.elapsedMs},
  Events.markViewedResult: {Props.scope, Props.result, Props.failureReason},
  Events.reactionSendSkipped: {Props.scope, Props.reason},
  Events.mediaLoaded: {
    Props.scope,
    Props.mediaKind,
    Props.network,
    Props.mediaLoadMs,
    Props.result,
  },
  Events.mediaExposure: {Props.scope, Props.mediaKind, Props.mediaExposureMs},
  Events.mediaTimeline: {
    Props.scope,
    Props.mediaKind,
    Props.network,
    Props.markViewedMs,
    Props.mediaReadyMs,
    Props.paintedMs,
    Props.recordStartMs,
  },
  Events.mediaReceivedSealState: {
    Props.sealState,
    Props.mediaKind,
    Props.scope,
    Props.mediaTypeRaw,
  },
  Events.recordingMediaOverlap: {
    Props.scope,
    Props.mediaKind,
    Props.network,
    Props.overlapMs,
    Props.overlapPct,
    Props.recordingStartOffsetMs,
    Props.recordingDurationMs,
    Props.mediaExposureMs,
  },
  // The activation funnel. Each step carries how long it took from this
  // install's first launch, which is what makes time-to-value answerable at
  // all; it is per-step rather than global because only these events are
  // measured against that clock.
  Events.registerStarted: {Props.method, Props.msSinceFirstLaunch},
  Events.otpVerified: {Props.result, Props.msSinceFirstLaunch},
  Events.signupCompleted: {Props.msSinceFirstLaunch},
  Events.firstMessageSent: {
    Props.scope,
    Props.messageType,
    Props.msSinceFirstLaunch,
  },
  Events.firstReactionReceived: {Props.msSinceFirstLaunch},
  Events.consentDecision: {Props.decision},
  Events.groupCreated: {Props.memberCountBucket, Props.msSinceFirstLaunch},
  Events.groupJoined: {Props.groupSizeBucket},
  Events.friendAdded: {Props.method, Props.msSinceFirstLaunch},
  // Onboarding walkthrough: which step, and whether it was asked for again.
  // No content, only the step's name.
  Events.walkthroughStepShown: {Props.step, Props.msSinceFirstLaunch},
  Events.walkthroughReplayed: {},
  // Demo Reacti: metadata-free by design — never reference the captured media.
  Events.demoOpened: {Props.msSinceFirstLaunch},
  Events.demoStarted: {},
  Events.demoReactionCompleted: {},
  // Invite loop: metadata-free (never the contact, code, or any PII).
  Events.inviteShared: {},
  Events.inviteOpened: {},
  Events.inviteConnected: {},
};
