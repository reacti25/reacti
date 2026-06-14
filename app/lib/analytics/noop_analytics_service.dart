import 'analytics_service.dart';

/// An [AnalyticsService] that does nothing.
///
/// The default implementation wired whenever analytics is disabled
/// (no keys — see [AnalyticsConfig]) and in any context where tracking must be
/// a guaranteed no-op. It still runs the allowlist/identity logic in the base
/// class (so behaviour is identical to a real service minus the network), then
/// drops the event in [dispatch].
class NoopAnalyticsService extends AnalyticsService {
  /// Creates a no-op analytics service.
  NoopAnalyticsService({super.context, super.hashSalt});

  @override
  void dispatch(String event, Map<String, Object?> properties) {
    // Intentionally empty: analytics is off / not wired.
  }
}
