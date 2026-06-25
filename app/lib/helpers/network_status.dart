import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Coarse, synchronously-readable network class for analytics segmentation and
/// (later) Wi-Fi-only media prefetch: `wifi` | `cellular` | `none` | `unknown`.
///
/// connectivity_plus reports asynchronously, but analytics emits need the value
/// synchronously at the instant of the event. [NetworkStatus] caches the latest
/// reading — refreshed from the connectivity stream — so [current] is a cheap
/// synchronous read. It stays `unknown` until [start] obtains the first reading.
class NetworkStatus {
  NetworkStatus._();

  /// Process-wide singleton — many widgets read [current] on the patent path.
  static final NetworkStatus instance = NetworkStatus._();

  String _current = 'unknown';
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// The latest known network class; `unknown` until [start] gets a reading.
  String get current => _current;

  /// Begins tracking connectivity: takes one immediate reading, then follows
  /// the change stream. Fire-and-forget and fail-safe — any platform error
  /// leaves [current] unchanged and never throws into startup. [connectivity]
  /// is injectable for tests. Idempotent: a second call won't double-subscribe.
  Future<void> start({Connectivity? connectivity}) async {
    final source = connectivity ?? Connectivity();
    try {
      _current = classify(await source.checkConnectivity());
    } catch (_) {
      // An unavailable platform channel must not break boot; keep the default.
    }
    _sub ??= source.onConnectivityChanged.listen(
      (results) => _current = classify(results),
      onError: (_) {},
    );
  }

  /// Cancels the change subscription (test teardown).
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Maps a connectivity reading to the coarse analytics class.
  ///
  /// Wi-Fi and ethernet are both unmetered → `wifi`; mobile → `cellular`; an
  /// empty list or explicit none → `none`; anything else (vpn / bluetooth /
  /// other / satellite-only) → `unknown`. When several transports are reported
  /// at once, the most informative unmetered one wins (wifi > cellular > none).
  static String classify(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return 'wifi';
    }
    if (results.contains(ConnectivityResult.mobile)) return 'cellular';
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'none';
    }
    return 'unknown';
  }
}
