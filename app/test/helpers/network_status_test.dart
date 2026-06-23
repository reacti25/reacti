// Pins the connectivity → analytics-class mapping used to segment the Phase-0
// media-timing baseline (and, later, Wi-Fi-only prefetch). Pure and channel-free
// — only the static [NetworkStatus.classify] is exercised.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/network_status.dart';

void main() {
  group('NetworkStatus.classify', () {
    test('wifi and ethernet are both the unmetered "wifi" class', () {
      expect(NetworkStatus.classify([ConnectivityResult.wifi]), 'wifi');
      expect(NetworkStatus.classify([ConnectivityResult.ethernet]), 'wifi');
    });

    test('mobile is "cellular"', () {
      expect(NetworkStatus.classify([ConnectivityResult.mobile]), 'cellular');
    });

    test('explicit none and an empty reading are both "none"', () {
      expect(NetworkStatus.classify([ConnectivityResult.none]), 'none');
      expect(NetworkStatus.classify([]), 'none');
    });

    test('vpn/bluetooth/other fall back to "unknown"', () {
      expect(NetworkStatus.classify([ConnectivityResult.vpn]), 'unknown');
      expect(NetworkStatus.classify([ConnectivityResult.bluetooth]), 'unknown');
      expect(NetworkStatus.classify([ConnectivityResult.other]), 'unknown');
    });

    test('when several transports are present the unmetered one wins', () {
      // Dual wifi+mobile → wifi (prefer unmetered).
      expect(
        NetworkStatus.classify([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ]),
        'wifi',
      );
      // Cellular alongside a satellite link → still cellular.
      expect(
        NetworkStatus.classify([
          ConnectivityResult.mobile,
          ConnectivityResult.satellite,
        ]),
        'cellular',
      );
    });
  });
}
