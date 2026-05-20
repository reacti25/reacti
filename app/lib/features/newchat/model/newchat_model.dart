/// Lightweight view model for a contact row on the new-chat screen.
///
/// Used to populate the "Contacts On Reacti" list with display data only.
class NewchatModel {
  /// The contact's display name.
  final String name;

  /// The contact's username/handle.
  final String username;

  /// URL of the contact's avatar image.
  final String imageUrl;

  /// Creates a [NewchatModel] with the required [name], [username] and
  /// [imageUrl].
  NewchatModel({
    required this.name,
    required this.username,
    required this.imageUrl,
  });
}
