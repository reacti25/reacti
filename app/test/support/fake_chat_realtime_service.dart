// Test double for ChatRealtimeService.
//
// The real service opens a Pusher websocket in `connect()`, which can't run
// under `flutter test`. This fake records the connect/dispose calls and the
// arguments the screen passed, and captures the screen's `onEvent` callback so
// a test can later drive the reconcile path by feeding it synthetic events —
// without any network. Install it by swapping `chatRealtimeServiceFactory`
// (see test setUp), and restore the original factory in tearDown.

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';

/// A [ChatRealtimeService] that never touches the network.
///
/// Captures what the screen passed to [connect] (token, subscriptions and the
/// `onEvent` callback) so tests can assert the wiring and, via [emit], deliver
/// a synthetic event to the screen's handler.
class FakeChatRealtimeService extends ChatRealtimeService {
  /// Number of times [connect] was called.
  int connectCount = 0;

  /// Number of times [dispose] was called.
  int disposeCount = 0;

  /// The auth token the screen passed to the most recent [connect].
  String? lastAuthToken;

  /// The subscriptions the screen passed to the most recent [connect].
  List<ChatChannelSubscription>? lastSubscriptions;

  /// The event handler the screen passed to the most recent [connect].
  void Function(ChannelReadEvent)? _onEvent;

  @override
  void connect({
    required String authToken,
    required List<ChatChannelSubscription> subscriptions,
    required void Function(ChannelReadEvent) onEvent,
  }) {
    connectCount++;
    lastAuthToken = authToken;
    lastSubscriptions = subscriptions;
    _onEvent = onEvent;
    // Intentionally no client/socket — the fake is offline.
  }

  /// Delivers [event] to the screen's captured `onEvent` handler, simulating
  /// an inbound realtime message. No-op if [connect] hasn't run yet.
  void emit(ChannelReadEvent event) => _onEvent?.call(event);

  @override
  void dispose() {
    disposeCount++;
  }
}
