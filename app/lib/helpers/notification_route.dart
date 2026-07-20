import 'all_routes.dart';

/// A resolved navigation target for a tapped push notification: the [route]
/// name and the [args] its screen expects.
class NotificationRoute {
  /// Creates a target for [route] with [args].
  const NotificationRoute(this.route, this.args);

  /// The named route to push (e.g. [Routes.inboxRoute]).
  final String route;

  /// The arguments map the route's screen reads.
  final Map<String, dynamic> args;

  @override
  bool operator ==(Object other) =>
      other is NotificationRoute &&
      other.route == route &&
      _mapEquals(other.args, args);

  @override
  int get hashCode => Object.hash(route, args.length);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

/// Decodes a push notification's FCM `data` map into a [NotificationRoute],
/// or `null` when the payload can't route (unknown/missing `type`, missing ids,
/// or non-numeric ids) — callers then just open the app normally.
///
/// Kept as pure data-in/data-out so tap routing is unit-tested without Firebase
/// or a navigator. The backend fills this map in `ChatService::send` /
/// `GroupMessageService::sendMessage`; FCM delivers all values as strings.
///
/// Recognised shapes:
/// * `type=chat_1to1` + `id`, `roomId` (numeric), optional `name`, `image`
///   → [Routes.inboxRoute].
/// * `type=chat_group` + `roomId` (numeric), optional `name`, `groupImage`
///   → [Routes.groupInboxRoute].
NotificationRoute? decodeNotificationRoute(Map<String, dynamic> data) {
  final type = data['type']?.toString();

  switch (type) {
    case 'chat_1to1':
      final id = int.tryParse(data['id']?.toString() ?? '');
      final roomId = int.tryParse(data['roomId']?.toString() ?? '');
      if (id == null || roomId == null) return null;
      return NotificationRoute(Routes.inboxRoute, {
        'id': id,
        'roomId': roomId,
        'name': data['name']?.toString() ?? '',
        'image': data['image']?.toString() ?? '',
      });

    case 'chat_group':
      final roomId = int.tryParse(data['roomId']?.toString() ?? '');
      if (roomId == null) return null;
      return NotificationRoute(Routes.groupInboxRoute, {
        'roomId': roomId,
        'name': data['name']?.toString() ?? '',
        'groupImage': data['groupImage']?.toString() ?? '',
      });

    default:
      return null;
  }
}
