import 'dart:convert';

/// Envelope returned by the user-profile endpoint.
///
/// Wraps the actual profile [Data] alongside the standard API status fields
/// so callers can distinguish success from failure and surface a message.
class ProfileResponse {
  /// Whether the request succeeded, as reported by the backend.
  bool? success;

  /// Human-readable status or error message from the backend.
  String? message;

  /// The profile payload, or `null` when absent (e.g. on failure).
  Data? data;

  /// Application-level status code returned alongside the HTTP status.
  int? code;

  /// Creates a [ProfileResponse]; every field is optional and nullable.
  ProfileResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  ProfileResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => ProfileResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Parses a [ProfileResponse] from a raw JSON [str].
  factory ProfileResponse.fromRawJson(String str) =>
      ProfileResponse.fromJson(json.decode(str));

  /// Serializes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [ProfileResponse] from a decoded JSON [json] map.
  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      ProfileResponse(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        code: json["code"],
      );

  /// Converts this response into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "code": code,
  };
}

/// The signed-in user's profile details returned inside [ProfileResponse].
class Data {
  /// Unique identifier of the user.
  int? id;

  /// The user's display name (first and last name combined).
  String? fullName;

  /// The user's first name.
  String? firstName;

  /// The user's last name.
  String? lastName;

  /// The user's unique handle.
  String? username;

  /// The user's email address.
  String? email;

  /// Free-text bio; typed as [dynamic] because the backend may send `null`
  /// or a non-string value.
  dynamic bio;

  /// The user's phone number.
  String? phone;

  /// URL of the user's avatar image.
  String? avatar;

  /// Number of accepted friends the user has.
  int? totalFriends;

  /// Number of groups the user belongs to.
  int? totalGroups;

  /// Account creation timestamp as an ISO-8601 string.
  String? createdAt;

  /// Creates a [Data]; every field is optional and nullable.
  Data({
    this.id,
    this.fullName,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.bio,
    this.phone,
    this.avatar,
    this.totalFriends,
    this.totalGroups,
    this.createdAt,
  });

  /// Returns a copy of this profile with the given fields overridden.
  Data copyWith({
    int? id,
    String? fullName,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    dynamic bio,
    String? phone,
    String? avatar,
    int? totalFriends,
    int? totalGroups,
    String? createdAt,
  }) => Data(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    username: username ?? this.username,
    email: email ?? this.email,
    bio: bio ?? this.bio,
    phone: phone ?? this.phone,
    avatar: avatar ?? this.avatar,
    totalFriends: totalFriends ?? this.totalFriends,
    totalGroups: totalGroups ?? this.totalGroups,
    createdAt: createdAt ?? this.createdAt,
  );

  /// Parses a [Data] from a raw JSON [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serializes this profile to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] from a decoded JSON [json] map, mapping the backend's
  /// snake_case keys onto camelCase fields.
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    id: json["id"],
    fullName: json["full_name"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    username: json["username"],
    email: json["email"],
    bio: json["bio"],
    phone: json["phone"],
    avatar: json["avatar"],
    totalFriends: json["total_friends"],
    totalGroups: json["total_groups"],
    createdAt: json["created_at"],
  );

  /// Converts this profile into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "id": id,
    "full_name": fullName,
    "first_name": firstName,
    "last_name": lastName,
    "username": username,
    "email": email,
    "bio": bio,
    "phone": phone,
    "avatar": avatar,
    "total_friends": totalFriends,
    "total_groups": totalGroups,
    "created_at": createdAt,
  };
}
