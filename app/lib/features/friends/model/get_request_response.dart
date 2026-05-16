import 'dart:convert';

/// The decoded response body of the friend-request endpoints (both incoming
/// and sent requests).
///
/// Wraps the standard API envelope (`success`, `message`, `code`) around a
/// [Data] payload that carries the paginated request list.
class GetRequestResponse {
  /// Whether the request succeeded, as reported by the server.
  bool? success;

  /// A human-readable status message from the server.
  String? message;

  /// The payload holding the request list and pagination details.
  Data? data;

  /// The application-level status code from the server.
  int? code;

  /// Creates a [GetRequestResponse]; all fields are optional.
  GetRequestResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
  GetRequestResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => GetRequestResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Builds a [GetRequestResponse] by decoding the raw JSON string [str].
  factory GetRequestResponse.fromRawJson(String str) =>
      GetRequestResponse.fromJson(json.decode(str));

  /// Serializes this response into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [GetRequestResponse] from an already-decoded JSON map [json].
  ///
  /// A missing or null `data` field yields a `null` [data].
  factory GetRequestResponse.fromJson(Map<String, dynamic> json) =>
      GetRequestResponse(
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

/// The payload of a [GetRequestResponse]: a page of friend requests plus the
/// pagination metadata describing it.
class Data {
  /// The friend requests on the current page, or an empty list when none.
  List<Request>? requests;

  /// Pagination metadata for the request list.
  Pagination? pagination;

  /// Creates a [Data] payload; both fields are optional.
  Data({this.requests, this.pagination});

  /// Returns a copy of this payload with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
  Data copyWith({List<Request>? requests, Pagination? pagination}) => Data(
    requests: requests ?? this.requests,
    pagination: pagination ?? this.pagination,
  );

  /// Builds a [Data] by decoding the raw JSON string [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serializes this payload into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] from an already-decoded JSON map [json].
  ///
  /// A missing or null `requests` field is normalized to an empty list.
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    requests:
        json["requests"] == null
            ? []
            : List<Request>.from(
              json["requests"]!.map((x) => Request.fromJson(x)),
            ),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  /// Converts this payload into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "requests":
        requests == null
            ? []
            : List<dynamic>.from(requests!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

/// Pagination metadata for a page of friend requests.
class Pagination {
  /// The total number of requests across all pages.
  int? total;

  /// The 1-based index of the page currently returned.
  int? currentPage;

  /// The index of the last available page.
  int? lastPage;

  /// The number of requests per page.
  int? perPage;

  /// Creates a [Pagination]; all fields are optional.
  Pagination({this.total, this.currentPage, this.lastPage, this.perPage});

  /// Returns a copy of this metadata with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
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

  /// Builds a [Pagination] by decoding the raw JSON string [str].
  factory Pagination.fromRawJson(String str) =>
      Pagination.fromJson(json.decode(str));

  /// Serializes this metadata into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Pagination] from an already-decoded JSON map [json].
  ///
  /// Maps the snake_case server keys onto the camelCase Dart fields.
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

/// A single friend request, either incoming or sent.
///
/// Carries the requesting/receiving [Person] together with the request's
/// lifecycle state (`status`, timestamps) and direction ([isSent]).
class Request {
  /// The request's unique id.
  int? id;

  /// The other party involved in the request.
  Person? person;

  /// The request's current status (for example pending, accepted, declined).
  String? status;

  /// The timestamp at which the request was sent.
  String? sentAt;

  /// The timestamp at which the request was accepted, or `null` if not yet
  /// accepted. Typed `dynamic` because the API may return a string or `null`.
  dynamic acceptedAt;

  /// The timestamp at which the request was declined, or `null` if not yet
  /// declined. Typed `dynamic` because the API may return a string or `null`.
  dynamic declinedAt;

  /// Whether the current user sent this request (`true`) or received it
  /// (`false`).
  bool? isSent;

  /// Creates a [Request]; all fields are optional.
  Request({
    this.id,
    this.person,
    this.status,
    this.sentAt,
    this.acceptedAt,
    this.declinedAt,
    this.isSent,
  });

  /// Returns a copy of this request with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
  Request copyWith({
    int? id,
    Person? person,
    String? status,
    String? sentAt,
    dynamic acceptedAt,
    dynamic declinedAt,
    bool? isSent,
  }) => Request(
    id: id ?? this.id,
    person: person ?? this.person,
    status: status ?? this.status,
    sentAt: sentAt ?? this.sentAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    declinedAt: declinedAt ?? this.declinedAt,
    isSent: isSent ?? this.isSent,
  );

  /// Builds a [Request] by decoding the raw JSON string [str].
  factory Request.fromRawJson(String str) => Request.fromJson(json.decode(str));

  /// Serializes this request into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Request] from an already-decoded JSON map [json].
  ///
  /// Maps the snake_case server keys onto the camelCase Dart fields.
  factory Request.fromJson(Map<String, dynamic> json) => Request(
    id: json["id"],
    person: json["person"] == null ? null : Person.fromJson(json["person"]),
    status: json["status"],
    sentAt: json["sent_at"],
    acceptedAt: json["accepted_at"],
    declinedAt: json["declined_at"],
    isSent: json["is_sent"],
  );

  /// Converts this request into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "id": id,
    "person": person?.toJson(),
    "status": status,
    "sent_at": sentAt,
    "accepted_at": acceptedAt,
    "declined_at": declinedAt,
    "is_sent": isSent,
  };
}

/// The profile of the other user attached to a friend [Request].
class Person {
  /// The user's unique id.
  int? id;

  /// The user's first name.
  String? firstName;

  /// The user's last name.
  String? lastName;

  /// The user's unique handle.
  String? username;

  /// The URL of the user's avatar image.
  String? avatar;

  /// The user's pre-composed full display name.
  String? fullName;

  /// Creates a [Person]; all fields are optional.
  Person({
    this.id,
    this.firstName,
    this.lastName,
    this.username,
    this.avatar,
    this.fullName,
  });

  /// Returns a copy of this profile with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
  Person copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? username,
    String? avatar,
    String? fullName,
  }) => Person(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    username: username ?? this.username,
    avatar: avatar ?? this.avatar,
    fullName: fullName ?? this.fullName,
  );

  /// Builds a [Person] by decoding the raw JSON string [str].
  factory Person.fromRawJson(String str) => Person.fromJson(json.decode(str));

  /// Serializes this profile into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Person] from an already-decoded JSON map [json].
  ///
  /// Maps the snake_case server keys onto the camelCase Dart fields.
  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    username: json["username"],
    avatar: json["avatar"],
    fullName: json["full_name"],
  );

  /// Converts this profile into a JSON-encodable map with snake_case keys.
  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "username": username,
    "avatar": avatar,
    "full_name": fullName,
  };
}
