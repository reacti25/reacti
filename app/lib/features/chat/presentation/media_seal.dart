/// Decides whether a chat message's media must be presented SEALED (blurred)
/// to the recipient, based on the API's `is_blurred` flag.
///
/// The flag reaches the client in two shapes:
///   * the conversation REST endpoint sends a JSON **bool** (`true`/`false`),
///   * the realtime/Pusher path sends an **int** (`1`/`0`).
///
/// In Dart `true == 1` is `false`, so a naive `isBlurred == 1` check left
/// history-loaded media UNSEALED for the receiver — which in turn disabled the
/// tap-to-view that fires `mark-viewed` and the silent reaction recording
/// (the patent flow). Treat either truthy form as sealed.
bool isMediaSealed(dynamic isBlurred) => isBlurred == true || isBlurred == 1;

/// Whether a message is a view-once ("one-time") send, from the API's
/// `is_one_time` flag.
///
/// Same loose shapes as [isMediaSealed] — a JSON bool over REST, an int over
/// realtime — so treat either truthy form as one-time.
bool isOneTime(dynamic oneTime) => oneTime == true || oneTime == 1;
