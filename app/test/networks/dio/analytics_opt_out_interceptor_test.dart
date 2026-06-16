// Pins the X-Analytics-Opt-Out header behaviour: the interceptor stamps the
// header only while the user is opted out, and re-reads the predicate per
// request so a mid-session toggle takes effect immediately. This is the
// app->backend "immediate" half of the analytics opt-out propagation.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/networks/dio/analytics_opt_out_interceptor.dart';
import 'package:reacti_app/networks/endpoints.dart';

/// Runs [interceptor.onRequest] over a fresh request and returns its headers
/// after the interceptor has (optionally) stamped them.
Map<String, dynamic> _headersAfter(AnalyticsOptOutInterceptor interceptor) {
  final options = RequestOptions(path: '/profile');
  interceptor.onRequest(options, RequestInterceptorHandler());
  return options.headers;
}

void main() {
  group('AnalyticsOptOutInterceptor', () {
    test('stamps the header when opted out', () {
      final interceptor = AnalyticsOptOutInterceptor(() => true);
      expect(
        _headersAfter(interceptor)[NetworkConstants.ANALYTICS_OPT_OUT],
        '1',
      );
    });

    test('omits the header when opted in', () {
      final interceptor = AnalyticsOptOutInterceptor(() => false);
      expect(
        _headersAfter(
          interceptor,
        ).containsKey(NetworkConstants.ANALYTICS_OPT_OUT),
        isFalse,
      );
    });

    test('re-reads the predicate per request (live toggle)', () {
      var optedOut = false;
      final interceptor = AnalyticsOptOutInterceptor(() => optedOut);

      expect(
        _headersAfter(
          interceptor,
        ).containsKey(NetworkConstants.ANALYTICS_OPT_OUT),
        isFalse,
      );

      optedOut = true; // user flips the toggle mid-session
      expect(
        _headersAfter(interceptor)[NetworkConstants.ANALYTICS_OPT_OUT],
        '1',
      );
    });
  });
}
