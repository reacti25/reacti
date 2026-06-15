import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics_service.dart';

/// [AnalyticsService] backed by the PostHog SDK.
///
/// Wired only when analytics is enabled (a key is configured — see
/// [AnalyticsConfig]); otherwise [NoopAnalyticsService] is used. The base class
/// has already applied the allowlist and hashed the user id by the time
/// [dispatch] is called, so this class only forwards the sanitised event to
/// PostHog.
///
/// **Fire-and-forget (design principle #5).** Every SDK call is dispatched
/// without awaiting and wrapped so a failing/slow analytics call can never throw
/// into, or block, the calling feature flow (e.g. a message send).
class PostHogAnalyticsService extends AnalyticsService {
  /// Creates the PostHog-backed service. [PostHog().setup] must have been called
  /// during bootstrap (see [AnalyticsBootstrap.initPostHog]).
  PostHogAnalyticsService({super.context, super.hashSalt});

  @override
  void dispatch(String event, Map<String, Object?> properties) {
    _fireAndForget(
      () => Posthog().capture(
        eventName: event,
        properties: postHogProperties(properties),
      ),
    );
  }

  /// Builds the PostHog property map from the sanitised [properties].
  ///
  /// Adds the `$geoip_disable` ingestion directive so PostHog does NOT attach
  /// IP-based GeoIP — city, subdivision **or** country — to the event. A
  /// face-recording app must not pin a pseudonymous user to a location; PostHog
  /// has no client-side "country only" granularity, so we disable IP geolocation
  /// outright. (Base class already dropped null values, so every value is
  /// non-null.)
  @visibleForTesting
  static Map<String, Object> postHogProperties(
    Map<String, Object?> properties,
  ) {
    return <String, Object>{
      for (final entry in properties.entries) entry.key: entry.value as Object,
      r'$geoip_disable': true,
    };
  }

  @override
  void identify(String rawUserId) {
    super.identify(rawUserId); // stores the hash; raw id never goes further
    final id = currentDistinctId;
    if (id.isEmpty) return;
    _fireAndForget(() => Posthog().identify(userId: id));
  }

  @override
  void reset() {
    super.reset();
    _fireAndForget(() => Posthog().reset());
  }

  /// Runs [op] without awaiting and swallows any error so analytics can never
  /// break or slow the caller.
  void _fireAndForget(Future<void> Function() op) {
    try {
      unawaited(op().catchError((Object _) {}));
    } catch (_) {
      // Even constructing the future must not throw into the caller.
    }
  }
}
