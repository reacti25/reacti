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

  // Messaging
  static const String messageSent = 'message_sent';
  static const String mediaUploaded = 'media_uploaded';
  static const String messageReceived = 'message_received';

  // Reaction / patent flow (metadata only — never the recorded media)
  static const String reactionRecorded = 'reaction_recorded';
  static const String reactionSent = 'reaction_sent';
  static const String reactionViewed = 'reaction_viewed';
  static const String markViewedToReaction = 'mark_viewed_to_reaction';

  // Growth & funnel
  static const String registerStarted = 'register_started';
  static const String otpVerified = 'otp_verified';
  static const String firstMessageSent = 'first_message_sent';
  static const String consentDecision = 'consent_decision';

  // Engagement & social graph
  static const String groupCreated = 'group_created';
  static const String groupJoined = 'group_joined';
  static const String friendAdded = 'friend_added';

  /// Every known event name — used by tests to assert allowlist completeness.
  static const Set<String> all = {
    appOpen,
    screenView,
    sessionStart,
    messageSent,
    mediaUploaded,
    messageReceived,
    reactionRecorded,
    reactionSent,
    reactionViewed,
    markViewedToReaction,
    registerStarted,
    otpVerified,
    firstMessageSent,
    consentDecision,
    groupCreated,
    groupJoined,
    friendAdded,
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
  static const String elapsedMs = 'elapsed_ms';
  static const String method = 'method';
  static const String decision = 'decision';
  static const String memberCountBucket = 'member_count_bucket';
  static const String groupSizeBucket = 'group_size_bucket';

  /// The seven global property keys, always allowed on every event.
  static const Set<String> globals = {
    distinctId,
    analyticsEnv,
    platform,
    appVersion,
    appBuild,
    sessionId,
    ts,
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
  Events.messageSent: {
    Props.messageType,
    Props.scope,
    Props.sendMs,
    Props.result,
    Props.hasReply,
  },
  Events.mediaUploaded: {
    Props.uploadMs,
    Props.sizeBucket,
    Props.network,
    Props.mediaKind,
    Props.result,
  },
  Events.messageReceived: {Props.messageType, Props.scope, Props.deliveryMs},
  Events.reactionRecorded: {
    Props.scope,
    Props.recordMs,
    Props.result,
    Props.failureReason,
  },
  Events.reactionSent: {
    Props.scope,
    Props.uploadMs,
    Props.sizeBucket,
    Props.result,
  },
  Events.reactionViewed: {Props.scope},
  Events.markViewedToReaction: {Props.scope, Props.elapsedMs},
  Events.registerStarted: {Props.method},
  Events.otpVerified: {Props.result},
  Events.firstMessageSent: {Props.scope},
  Events.consentDecision: {Props.decision},
  Events.groupCreated: {Props.memberCountBucket},
  Events.groupJoined: {Props.groupSizeBucket},
  Events.friendAdded: {},
};
