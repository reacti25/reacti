import 'dart:convert';

/// Envelope returned by the user-search endpoint.
///
/// Carries the standard `success`/`message`/`code` fields plus the paginated
/// [Data] payload of matching users.
class AllUserResponse {
  /// Whether the backend reported the search as successful.
  bool? success;

  /// Human-readable status or error message from the backend.
  String? message;

  /// The paginated search-result payload, or `null` when absent.
  Data? data;

  /// Backend status/result code accompanying the response.
  int? code;

  /// Creates an [AllUserResponse] with all fields optional.
  AllUserResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  AllUserResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => AllUserResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Builds an [AllUserResponse] from a raw JSON string [str].
  factory AllUserResponse.fromRawJson(String str) =>
      AllUserResponse.fromJson(json.decode(str));

  /// Serializes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds an [AllUserResponse] from a decoded JSON map [json].
  factory AllUserResponse.fromJson(Map<String, dynamic> json) =>
      AllUserResponse(
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

/// The paginated search-result payload of an [AllUserResponse].
///
/// Holds the page of matching users in [data] and its [Pagination] metadata.
class Data {
  /// The list of users matching the search on the current page.
  List<Datum>? data;

  /// Pagination metadata describing the result set.
  Pagination? pagination;

  /// Creates a [Data] payload with an optional user list and pagination.
  Data({this.data, this.pagination});

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({List<Datum>? data, Pagination? pagination}) =>
      Data(data: data ?? this.data, pagination: pagination ?? this.pagination);

  /// Builds a [Data] payload from a raw JSON string [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serializes this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] payload from a decoded JSON map [json].
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    data:
        json["data"] == null
            ? []
            : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  /// Converts this payload into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "data":
        data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

/// A single user record in a search result.
///
/// The [isFriend] and [isRequestSent] flags let the search screen decide
/// whether to show a "Message", "Send Request" or "Cancel" action.
class Datum {
  /// Unique identifier of the user.
  int? id;

  /// The user's full display name.
  String? fullName;

  /// The user's unique handle/username.
  String? username;

  /// URL of the user's avatar image.
  String? avatar;

  /// Whether the searching user is already friends with this user.
  bool? isFriend;

  /// Whether the searching user has a pending request sent to this user.
  bool? isRequestSent;

  /// Creates a [Datum] user record with all fields optional.
  Datum({
    this.id,
    this.fullName,
    this.username,
    this.avatar,
    this.isFriend,
    this.isRequestSent,
  });

  /// Returns a copy of this user with the given fields overridden.
  Datum copyWith({
    int? id,
    String? fullName,
    String? username,
    String? avatar,
    bool? isFriend,
    bool? isRequestSent,
  }) => Datum(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    username: username ?? this.username,
    avatar: avatar ?? this.avatar,
    isFriend: isFriend ?? this.isFriend,
    isRequestSent: isRequestSent ?? this.isRequestSent,
  );

  /// Builds a [Datum] user from a raw JSON string [str].
  factory Datum.fromRawJson(String str) => Datum.fromJson(json.decode(str));

  /// Serializes this user to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Datum] user from a decoded JSON map [json].
  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    fullName: json["full_name"],
    username: json["username"],
    avatar: json["avatar"],
    isFriend: json["is_friend"],
    isRequestSent: json["is_request_sent"],
  );

  /// Converts this user into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "full_name": fullName,
    "username": username,
    "avatar": avatar,
    "is_friend": isFriend,
    "is_request_sent": isRequestSent,
  };
}

/// Pagination metadata for a paged user-search result.
class Pagination {
  /// Total number of matching users across all pages.
  int? total;

  /// The 1-based index of the current page.
  int? currentPage;

  /// The index of the last available page.
  int? lastPage;

  /// Number of items returned per page.
  int? perPage;

  /// Creates a [Pagination] descriptor with all fields optional.
  Pagination({this.total, this.currentPage, this.lastPage, this.perPage});

  /// Returns a copy of this descriptor with the given fields overridden.
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

  /// Builds a [Pagination] descriptor from a raw JSON string [str].
  factory Pagination.fromRawJson(String str) =>
      Pagination.fromJson(json.decode(str));

  /// Serializes this descriptor to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Pagination] descriptor from a decoded JSON map [json].
  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    total: json["total"],
    currentPage: json["current_page"],
    lastPage: json["last_page"],
    perPage: json["per_page"],
  );

  /// Converts this descriptor into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "total": total,
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
  };
}
