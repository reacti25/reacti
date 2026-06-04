import 'dart:convert';

/// Top-level envelope returned by the group-details endpoint.
///
/// Wraps the API's standard `success` / `message` / `code` metadata around
/// the [Data] payload that carries the actual [Group].
class GroupDetailsResponse {
  /// Whether the request succeeded server-side.
  bool? success;

  /// Human-readable status message from the server.
  String? message;

  /// The payload holding the resolved [Group].
  Data? data;

  /// Application-level status code accompanying the response.
  int? code;

  /// Creates a [GroupDetailsResponse] from optional named fields.
  GroupDetailsResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  GroupDetailsResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => GroupDetailsResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Parses a [GroupDetailsResponse] from a raw JSON [str].
  factory GroupDetailsResponse.fromRawJson(String str) =>
      GroupDetailsResponse.fromJson(json.decode(str));

  /// Serialises this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [GroupDetailsResponse] from a decoded JSON map.
  factory GroupDetailsResponse.fromJson(Map<String, dynamic> json) =>
      GroupDetailsResponse(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        code: json["code"],
      );

  /// Serialises this response to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "code": code,
  };
}

/// Payload of [GroupDetailsResponse] holding the resolved [Group].
class Data {
  /// The group whose details were requested.
  Group? group;

  /// Creates a [Data] payload from an optional [group].
  Data({this.group});

  /// Returns a copy of this payload with [group] overridden.
  Data copyWith({Group? group}) => Data(group: group ?? this.group);

  /// Parses a [Data] payload from a raw JSON [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serialises this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Data] payload from a decoded JSON map.
  factory Data.fromJson(Map<String, dynamic> json) =>
      Data(group: json["group"] == null ? null : Group.fromJson(json["group"]));

  /// Serialises this payload to a JSON-encodable map.
  Map<String, dynamic> toJson() => {"group": group?.toJson()};
}

/// A group chat with its profile, membership and creator information.
class Group {
  /// Unique group identifier.
  int? id;

  /// Display name of the group.
  String? name;

  /// Optional description shown on the group profile.
  String? description;

  /// URL of the group's avatar image.
  String? avatar;

  /// Whether the current user has admin rights in this group.
  bool? isAdmin;

  /// Total number of members in the group.
  int? memberCount;

  /// ISO timestamp of when the group was created.
  String? createdAt;

  /// ISO timestamp of the group's last update.
  String? updatedAt;

  /// The user who created the group.
  Creator? creator;

  /// The full member list of the group.
  List<Member>? members;

  /// Creates a [Group] from optional named fields.
  Group({
    this.id,
    this.name,
    this.description,
    this.avatar,
    this.isAdmin,
    this.memberCount,
    this.createdAt,
    this.updatedAt,
    this.creator,
    this.members,
  });

  /// Returns a copy of this group with the given fields overridden.
  Group copyWith({
    int? id,
    String? name,
    String? description,
    String? avatar,
    bool? isAdmin,
    int? memberCount,
    String? createdAt,
    String? updatedAt,
    Creator? creator,
    List<Member>? members,
  }) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    avatar: avatar ?? this.avatar,
    isAdmin: isAdmin ?? this.isAdmin,
    memberCount: memberCount ?? this.memberCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    creator: creator ?? this.creator,
    members: members ?? this.members,
  );

  /// Parses a [Group] from a raw JSON [str].
  factory Group.fromRawJson(String str) => Group.fromJson(json.decode(str));

  /// Serialises this group to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Group] from a decoded JSON map.
  ///
  /// A missing `members` array is normalised to an empty list rather than
  /// `null` so callers can iterate without a null check.
  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json["id"],
    name: json["name"],
    description: json["description"],
    avatar: json["avatar"],
    isAdmin: json["is_admin"],
    memberCount: json["member_count"],
    createdAt: json["created_at"],
    updatedAt: json["updated_at"],
    creator: json["creator"] == null ? null : Creator.fromJson(json["creator"]),
    members:
        json["members"] == null
            ? []
            : List<Member>.from(
              json["members"]!.map((x) => Member.fromJson(x)),
            ),
  );

  /// Serialises this group to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "description": description,
    "avatar": avatar,
    "is_admin": isAdmin,
    "member_count": memberCount,
    "created_at": createdAt,
    "updated_at": updatedAt,
    "creator": creator?.toJson(),
    "members":
        members == null
            ? []
            : List<dynamic>.from(members!.map((x) => x.toJson())),
  };
}

/// A user profile, used both for a group's creator and for member users.
class Creator {
  /// Unique user identifier.
  int? id;

  /// User's first name.
  String? firstName;

  /// User's last name.
  String? lastName;

  /// User's email address.
  String? email;

  /// URL of the user's avatar image.
  String? avatar;

  /// ISO timestamp of the user's last recorded activity.
  String? lastActivityAt;

  /// Creates a [Creator] from optional named fields.
  Creator({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.avatar,
    this.lastActivityAt,
  });

  /// Returns a copy of this user with the given fields overridden.
  Creator copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
    String? lastActivityAt,
  }) => Creator(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    avatar: avatar ?? this.avatar,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
  );

  /// Parses a [Creator] from a raw JSON [str].
  factory Creator.fromRawJson(String str) => Creator.fromJson(json.decode(str));

  /// Serialises this user to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Creator] from a decoded JSON map.
  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    email: json["email"],
    avatar: json["avatar"],
    lastActivityAt: json["last_activity_at"],
  );

  /// Serialises this user to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "email": email,
    "avatar": avatar,
    "last_activity_at": lastActivityAt,
  };
}

/// A single membership entry linking a [Creator] user to a group.
class Member {
  /// Unique membership identifier.
  int? id;

  /// The user's role within the group, e.g. `owner`, `admin` or `member`.
  String? role;

  /// ISO timestamp of when the user joined the group.
  String? joinedAt;

  /// The user profile this membership belongs to.
  Creator? user;

  /// Creates a [Member] from optional named fields.
  Member({this.id, this.role, this.joinedAt, this.user});

  /// Returns a copy of this membership with the given fields overridden.
  Member copyWith({int? id, String? role, String? joinedAt, Creator? user}) =>
      Member(
        id: id ?? this.id,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
        user: user ?? this.user,
      );

  /// Parses a [Member] from a raw JSON [str].
  factory Member.fromRawJson(String str) => Member.fromJson(json.decode(str));

  /// Serialises this membership to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Member] from a decoded JSON map.
  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json["id"],
    role: json["role"],
    joinedAt: json["joined_at"],
    user: json["user"] == null ? null : Creator.fromJson(json["user"]),
  );

  /// Serialises this membership to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "role": role,
    "joined_at": joinedAt,
    "user": user?.toJson(),
  };
}
