// Tests for PostHogAnalyticsService.postHogProperties — the vendor-layer mapping
// that disables IP-based GeoIP so PostHog never attaches a location (city/region/
// country) to a pseudonymous user. (The capture/identify SDK calls hit a method
// channel and are covered by the on-device staging check, not unit tests.)

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/analytics/posthog_analytics_service.dart';

void main() {
  group('PostHogAnalyticsService.postHogProperties', () {
    test('sets \$geoip_disable so no IP-based location is captured', () {
      final props = PostHogAnalyticsService.postHogProperties({
        Props.scope: 'private',
      });
      expect(props[r'$geoip_disable'], isTrue);
    });

    test('passes the sanitised event properties through unchanged', () {
      final props = PostHogAnalyticsService.postHogProperties({
        Props.scope: 'group',
        Props.sendMs: 120,
      });
      expect(props[Props.scope], 'group');
      expect(props[Props.sendMs], 120);
    });
  });
}
