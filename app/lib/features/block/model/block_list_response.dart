import 'dart:convert';

/// Envelope returned by the blocked-user-list endpoint.
///
/// Wraps the paginated [Data] payload alongside the standard API status
/// fields.
class BlockListResponse {
  /// Whether the request succeeded, as reported by the backend.
  bool? success;

  /// Human-readable status or error message from the backend.
  String? message;

  /// The blocked-user payload, or `null` when absent (e.g. on failure).
  Data? data;

  /// Application-level status code returned alongside the HTTP status.
  int? code;

  /// Creates a [BlockListResponse]; every field is optional and nullable.
  BlockListResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  BlockListResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => BlockListResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Parses a [BlockListResponse] from a raw JSON [str].
  factory BlockListResponse.fromRawJson(String str) =>
      BlockListResponse.fromJson(json.decode(str));

  /// Serializes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [BlockListResponse] from a decoded JSON [json] map.
  factory BlockListResponse.fromJson(Map<String, dynamic> json) =>
      BlockListResponse(
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

/// The paginated blocked-user payload carried by [BlockListResponse].
class Data {
  /// The blocked-user entries for the current page.
  List<BlockedUserElement>? blockedUsers;

  /// Pagination metadata for the blocked-user list.
  Pagination? pagination;

  /// Creates a [Data]; both fields are optional and nullable.
  Data({this.blockedUsers, this.pagination});

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({
    List<BlockedUserElement>? blockedUsers,
    Pagination? pagination,
  }) => Data(
    blockedUsers: blockedUsers ?? this.blockedUsers,
    pagination: pagination ?? this.pagination,
  );

  /// Parses a [Data] from a raw JSON [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serializes this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] from a decoded JSON [json] map; a missing
  /// `blocked_users` key yields an empty list rather than `null`.
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    blockedUsers:
        json["blocked_users"] == null
            ? []
            : List<BlockedUserElement>.from(
              json["blocked_users"]!.map((x) => BlockedUserElement.fromJson(x)),
            ),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  /// Converts this payload into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "blocked_users":
        blockedUsers == null
            ? []
            : List<dynamic>.from(blockedUsers!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

/// A single entry in the blocked-user list.
///
/// Represents one block record: the block-record id, the id of the user who
/// was blocked, when the block was created, and the blocked user's profile.
class BlockedUserElement {
  /// Unique identifier of this block record.
  int? id;

  /// Identifier of the user that was blocked.
  int? blockUserId;

  /// Timestamp the block was created, as an ISO-8601 string.
  String? createdAt;

  /// Profile summary of the blocked user.
  BlockedUserBlockedUser? blockedUser;

  /// Creates a [BlockedUserElement]; every field is optional and nullable.
  BlockedUserElement({
    this.id,
    this.blockUserId,
    this.createdAt,
    this.blockedUser,
  });

  /// Returns a copy of this entry with the given fields overridden.
  BlockedUserElement copyWith({
    int? id,
    int? blockUserId,
    String? createdAt,
    BlockedUserBlockedUser? blockedUser,
  }) => BlockedUserElement(
    id: id ?? this.id,
    blockUserId: blockUserId ?? this.blockUserId,
    createdAt: createdAt ?? this.createdAt,
    blockedUser: blockedUser ?? this.blockedUser,
  );

  /// Parses a [BlockedUserElement] from a raw JSON [str].
  factory BlockedUserElement.fromRawJson(String str) =>
      BlockedUserElement.fromJson(json.decode(str));

  /// Serializes this entry to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [BlockedUserElement] from a decoded JSON [json] map.
  factory BlockedUserElement.fromJson(Map<String, dynamic> json) =>
      BlockedUserElement(
        id: json["id"],
        blockUserId: json["block_user_id"],
        createdAt: json["created_at"],
        blockedUser:
            json["blocked_user"] == null
                ? null
                : BlockedUserBlockedUser.fromJson(json["blocked_user"]),
      );

  /// Converts this entry into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "id": id,
    "block_user_id": blockUserId,
    "created_at": createdAt,
    "blocked_user": blockedUser?.toJson(),
  };
}

/// Profile summary of a blocked user, embedded in [BlockedUserElement].
class BlockedUserBlockedUser {
  /// Unique identifier of the blocked user.
  int? id;

  /// The blocked user's display name.
  String? fullName;

  /// The blocked user's first name.
  String? firstName;

  /// The blocked user's last name.
  String? lastName;

  /// The blocked user's unique handle.
  String? username;

  /// URL of the blocked user's avatar image.
  String? avatar;

  /// Creates a [BlockedUserBlockedUser]; every field is optional and nullable.
  BlockedUserBlockedUser({
    this.id,
    this.fullName,
    this.firstName,
    this.lastName,
    this.username,
    this.avatar,
  });

  /// Returns a copy of this summary with the given fields overridden.
  BlockedUserBlockedUser copyWith({
    int? id,
    String? fullName,
    String? firstName,
    String? lastName,
    String? username,
    String? avatar,
  }) => BlockedUserBlockedUser(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    username: username ?? this.username,
    avatar: avatar ?? this.avatar,
  );

  /// Parses a [BlockedUserBlockedUser] from a raw JSON [str].
  factory BlockedUserBlockedUser.fromRawJson(String str) =>
      BlockedUserBlockedUser.fromJson(json.decode(str));

  /// Serializes this summary to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [BlockedUserBlockedUser] from a decoded JSON [json] map.
  factory BlockedUserBlockedUser.fromJson(Map<String, dynamic> json) =>
      BlockedUserBlockedUser(
        id: json["id"],
        fullName: json["full_name"],
        firstName: json["first_name"],
        lastName: json["last_name"],
        username: json["username"],
        avatar: json["avatar"],
      );

  /// Converts this summary into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "id": id,
    "full_name": fullName,
    "first_name": firstName,
    "last_name": lastName,
    "username": username,
    "avatar": avatar,
  };
}

/// Pagination metadata describing a page of the blocked-user list.
class Pagination {
  /// Total number of blocked users across all pages.
  int? total;

  /// 1-based index of the current page.
  int? currentPage;

  /// Index of the last available page.
  int? lastPage;

  /// Number of items per page.
  int? perPage;

  /// Creates a [Pagination]; every field is optional and nullable.
  Pagination({this.total, this.currentPage, this.lastPage, this.perPage});

  /// Returns a copy of this metadata with the given fields overridden.
  Pagination copyWith({
    int? total,
    int? currentPage,
    int? lastPage,
    int? perPage,
  }) => Pagination(
    total: total ?? this.total,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    perPage: perPage ?? this.perPage,
  );

  /// Parses a [Pagination] from a raw JSON [str].
  factory Pagination.fromRawJson(String str) =>
      Pagination.fromJson(json.decode(str));

  /// Serializes this metadata to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Pagination] from a decoded JSON [json] map.
  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    total: json["total"],
    currentPage: json["current_page"],
    lastPage: json["last_page"],
    perPage: json["per_page"],
  );

  /// Converts this metadata into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "total": total,
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
  };
}
