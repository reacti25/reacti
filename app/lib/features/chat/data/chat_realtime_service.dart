import 'dart:async';
import 'dart:developer';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:rxdart/rxdart.dart';

/// Describes a single realtime binding: the Pusher private channel to
/// subscribe to and the broadcast event name to listen for on it.
///
/// A screen passes a list of these to [ChatRealtimeService.connect]. Two
/// subscriptions may share the same [channelName] (in which case only one
/// underlying private channel is created) while binding different
/// [eventName]s — this preserves the per-channel event pairing used by the
/// conversations screen.
class ChatChannelSubscription {
  /// Name of the Pusher private channel, e.g. `private-chat-room.42`.
  ///
  /// The leading `private-` prefix is expected exactly as the screens pass
  /// it today; the value is forwarded verbatim to [PusherChannelsClient.privateChannel].
  final String channelName;

  /// Fully-qualified broadcast event name to bind on [channelName], e.g.
  /// `App\Events\MessageSendEvent`.
  final String eventName;

  /// Creates a binding pairing [channelName] with [eventName].
  const ChatChannelSubscription({
    required this.channelName,
    required this.eventName,
  });
}

/// Owns the Pusher realtime connection boilerplate shared by the chat
/// screens.
///
/// This service centralises what was previously copy-pasted into each
/// screen's `connect()` method: building the host options, creating the
/// websocket client (with its connection-error handler), constructing the
/// private-channel auth delegates, subscribing on connection-established and
/// merging the bound event streams into one callback. Screen-specific event
/// handling stays in the caller via the `onEvent` callback passed to
/// [connect].
///
/// Lifecycle: create one instance per screen as a `final` field, call
/// [connect] from `initState`, and call [dispose] from the screen's
/// `dispose`.
class ChatRealtimeService {
  /// The Pusher websocket client, created in [connect].
  PusherChannelsClient? _client;

  /// Subscription to the client's connection-established stream.
  StreamSubscription? _connectionSubs;

  /// Merged subscription to every bound channel event stream.
  StreamSubscription<ChannelReadEvent>? _eventSubs;

  /// Opens the Pusher websocket connection and wires up the given
  /// [subscriptions].
  ///
  /// Builds the shared host options, creates the websocket client with the
  /// standard connection-error handler, then creates one private channel per
  /// distinct [ChatChannelSubscription.channelName] — each authorized with an
  /// [EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel]
  /// delegate carrying a `Bearer` [authToken] header. On
  /// `onConnectionEstablished` every distinct channel is subscribed, then each
  /// subscription's event is bound and all the resulting event streams are
  /// merged (via [Rx.merge]) into a single subscription that invokes
  /// [onEvent]. Finally the client connects.
  ///
  /// The subscribe-on-connection-established-then-connect ordering matches
  /// what the screens did individually.
  ///
  /// [authToken] is the current user's access token.
  /// [subscriptions] is the list of channel/event pairs the screen needs;
  /// pairs sharing a channel name reuse the same underlying channel.
  /// [onEvent] receives every event delivered by any bound subscription.
  void connect({
    required String authToken,
    required List<ChatChannelSubscription> subscriptions,
    required void Function(ChannelReadEvent) onEvent,
  }) {
    const hostOptions = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: 'climbiq-goonclimbers.com',
      key: 'd3d9ba606e9065ff0c3d1d566ccf904c',
      shouldSupplyMetadataQueries: true,
      metadata: PusherChannelsOptionsMetadata.byDefault(),
      port: 8081,
    );

    final client = PusherChannelsClient.websocket(
      options: hostOptions,
      connectionErrorHandler: (exception, trace, refresh) async {
        log("Connection error: $exception", error: trace);
        refresh();
      },
    );
    _client = client;

    // Create one private channel per distinct channel name, so two
    // subscriptions on the same channel reuse a single channel object.
    final Map<String, PrivateChannel> channels = {};
    for (final subscription in subscriptions) {
      channels.putIfAbsent(
        subscription.channelName,
        () => client.privateChannel(
          subscription.channelName,
          authorizationDelegate:
              EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
                authorizationEndpoint: Uri.parse(
                  "https://reacti.io/api/broadcasting/auth",
                ),
                headers: {"Authorization": "Bearer $authToken"},
              ),
        ),
      );
    }

    // Subscribe every distinct channel once the connection is established.
    _connectionSubs = client.onConnectionEstablished.listen((_) {
      log('==================== Connected to server =====================');
      for (final channel in channels.values) {
        channel.subscribeIfNotUnsubscribed();
      }
    });

    // Bind each subscription's event on its channel and merge the streams so
    // a single listener delivers every event to the caller.
    _eventSubs = Rx.merge(
      subscriptions
          .map(
            (subscription) => channels[subscription.channelName]!.bind(
              subscription.eventName,
            ),
          )
          .toList(),
    ).listen(onEvent);

    client.connect();
  }

  /// Cancels the connection and event subscriptions and disconnects the
  /// client.
  ///
  /// Mirrors the dispose triplet each screen previously inlined; safe to call
  /// even if [connect] was never invoked.
  void dispose() {
    _connectionSubs?.cancel();
    _eventSubs?.cancel();
    _client?.disconnect();
  }
}

/// Factory the chat screens use to obtain their [ChatRealtimeService].
///
/// In production this returns a real [ChatRealtimeService]. It exists as a
/// swappable seam so a widget/integration test can substitute a fake that
/// fires synthetic events instead of opening a real Pusher websocket — letting
/// `InboxScreen` / `GroupInboxScreen` be pumped without a live connection.
/// Tests must restore the original factory in `tearDown`.
ChatRealtimeService Function() chatRealtimeServiceFactory =
    () => ChatRealtimeService();
