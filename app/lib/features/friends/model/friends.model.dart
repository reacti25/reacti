/// A lightweight, immutable representation of a friend used for in-app
/// display purposes.
///
/// Unlike the JSON-backed response models, this holds only the fields the UI
/// needs to render a friend entry.
class FriendsModel {
  /// The friend's display name.
  final String name;

  /// The friend's unique handle.
  final String username;

  /// The URL of the friend's avatar image.
  final String imageUrl;

  /// Creates a [FriendsModel]; all fields are required.
  FriendsModel({
    required this.name,
    required this.username,
    required this.imageUrl,
  });
}
