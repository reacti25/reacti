import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/realtime_config.dart';

/// Guards that the realtime connection config is sourced from build-time
/// [RealtimeConfig] (not inline literals) and that its production defaults
/// still match the endpoint the live App Store app uses.
///
/// A2 moved the host/port/key/auth-URL out of `ChatRealtimeService` into
/// `--dart-define`-backed config. Per Achia's instruction the defaults must
/// reproduce the CURRENT production values so live messaging does not change;
/// this test pins those defaults so a careless edit can't silently repoint
/// realtime. A deliberate environment override (`--dart-define`) still wins at
/// build time — these assertions run with no defines, so they see the defaults.
void main() {
  group('RealtimeConfig production defaults', () {
    test('scheme is wss', () {
      expect(RealtimeConfig.scheme, 'wss');
    });

    test('host is the current production realtime host', () {
      expect(RealtimeConfig.host, 'climbiq-goonclimbers.com');
    });

    test('port is 8081', () {
      expect(RealtimeConfig.port, 8081);
    });

    test('key is the current production app key', () {
      expect(RealtimeConfig.key, 'd3d9ba606e9065ff0c3d1d566ccf904c');
    });

    test('auth URL is the production broadcasting/auth endpoint', () {
      expect(RealtimeConfig.authUrl, 'https://reacti.io/api/broadcasting/auth');
    });
  });
}
