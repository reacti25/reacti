import 'package:dio/dio.dart';

import '../endpoints.dart';

/// Dio interceptor that stamps the [NetworkConstants.ANALYTICS_OPT_OUT] header
/// on every outgoing request while the user is opted OUT of analytics.
///
/// The backend reads this header and emits no analytics event carrying the
/// user's id for that request — the *immediate* half of the opt-out
/// propagation (the persisted `users.analytics_opt_out` flag, set via
/// [EndPoints.analyticsOptOut], is the durable half). The opt-out state is read
/// live per request via [_isOptedOut], so flipping the toggle takes effect on
/// the very next call without rebuilding the client.
///
/// [_isOptedOut] is injected (rather than reading storage directly) so the
/// interceptor stays decoupled from the persistence layer and is trivially
/// testable.
class AnalyticsOptOutInterceptor extends Interceptor {
  /// Creates the interceptor over the live opt-out predicate [isOptedOut].
  AnalyticsOptOutInterceptor(bool Function() isOptedOut)
    : _isOptedOut = isOptedOut;

  /// Returns `true` when the user has opted out, evaluated per request.
  final bool Function() _isOptedOut;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isOptedOut()) {
      options.headers[NetworkConstants.ANALYTICS_OPT_OUT] = '1';
    }
    handler.next(options);
  }
}
