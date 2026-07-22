/// The public profile of a user who sent an invite (Feature 5).
///
/// Parsed from `GET /invites/{code}` — display fields only, never PII.
class Inviter {
  /// The inviter's user id.
  final int id;

  /// The inviter's first name (used in the "{Inviter} invited you" copy).
  final String firstName;

  /// The inviter's last name, possibly empty.
  final String lastName;

  /// The inviter's @username, if set.
  final String? username;

  /// The inviter's avatar URL, if set.
  final String? avatar;

  /// Creates an [Inviter].
  const Inviter({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.username,
    this.avatar,
  });

  /// Parses an [Inviter] from the resolve endpoint's `data` object.
  factory Inviter.fromJson(Map<String, dynamic> json) => Inviter(
    id: json['id'] as int,
    firstName: (json['first_name'] ?? '') as String,
    lastName: (json['last_name'] ?? '') as String,
    username: json['username'] as String?,
    avatar: json['avatar'] as String?,
  );

  /// Full display name, trimmed; falls back to the first name alone.
  String get displayName =>
      lastName.isNotEmpty ? '$firstName $lastName'.trim() : firstName;
}
