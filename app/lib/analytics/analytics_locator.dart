import '../helpers/di.dart';
import 'analytics_service.dart';
import 'noop_analytics_service.dart';

/// Process-wide fallback used when no [AnalyticsService] is registered (e.g. a
/// widget/unit test that doesn't set up DI). Guarantees [analytics] never throws.
final AnalyticsService _fallback = NoopAnalyticsService();

/// The active [AnalyticsService]: the DI-registered instance in the running app
/// (a PostHog-backed or no-op service — see `diSetUp`), or a no-op fallback when
/// none is registered.
///
/// Feature code uses this so a fire-and-forget tracking call is always safe and
/// never depends on a vendor SDK or on DI having been wired in a given test.
AnalyticsService get analytics =>
    locator.isRegistered<AnalyticsService>()
        ? locator<AnalyticsService>()
        : _fallback;
