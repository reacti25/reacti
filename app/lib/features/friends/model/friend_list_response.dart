import 'dart:convert';

/// The decoded response body of the get-friend-list endpoint.
///
/// Wraps the standard API envelope (`success`, `message`, `code`) around a
/// list of [Datum] friend entries.
class FriendListResponse {
  /// Whether the request succeeded, as reported by the server.
  bool? success;

  /// A human-readable status message from the server.
  String? message;

  /// The list of friends returned, or an empty list when none are present.
  List<Datum>? data;

  /// The application-level status code from the server.
  int? code;

  /// Creates a [FriendListResponse]; all fields are optional.
  FriendListResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
  FriendListResponse copyWith({
    bool? success,
    String? message,
    List<Datum>? data,
    int? code,
  }) => FriendListResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Builds a [FriendListResponse] by decoding the raw JSON string [str].
  factory FriendListResponse.fromRawJson(String str) =>
      FriendListResponse.fromJson(json.decode(str));

  /// Serializes this response into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [FriendListResponse] from an already-decoded JSON map [json].
  ///
  /// A missing or null `data` field is normalized to an empty list.
  factory FriendListResponse.fromJson(Map<String, dynamic> json) =>
      FriendListResponse(
        success: json["success"],
        message: json["message"],
        data:
            json["data"] == null
                ? []
                : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
        code: json["code"],
      );

  /// Converts this response into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data":
        data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "code": code,
  };
}

/// A single friend entry within a [FriendListResponse].
///
/// Models a friend's basic profile fields as returned by the API.
class Datum {
  /// The friend's unique user id.
  int? id;

  /// The friend's display name.
  String? name;

  /// The friend's handle; typed as `dynamic` because the API may return it
  /// as either a string or `null`.
  dynamic username;

  /// The friend's email address.
  String? email;

  /// The friend's phone number.
  String? phone;

  /// The URL of the friend's avatar image.
  String? avatar;

  /// Creates a [Datum]; all fields are optional.
  Datum({
    this.id,
    this.name,
    this.username,
    this.email,
    this.phone,
    this.avatar,
  });

  /// Returns a copy of this entry with the given fields replaced.
  ///
  /// Any argument left `null` keeps the current value.
  Datum copyWith({
    int? id,
    String? name,
    dynamic username,
    String? email,
    String? phone,
    String? avatar,
  }) => Datum(
    id: id ?? this.id,
    name: name ?? this.name,
    username: username ?? this.username,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    avatar: avatar ?? this.avatar,
  );

  /// Builds a [Datum] by decoding the raw JSON string [str].
  factory Datum.fromRawJson(String str) => Datum.fromJson(json.decode(str));

  /// Serializes this entry into a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Datum] from an already-decoded JSON map [json].
  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    name: json["name"],
    username: json["username"],
    email: json["email"],
    phone: json["phone"],
    avatar: json["avatar"],
  );

  /// Converts this entry into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "username": username,
    "email": email,
    "phone": phone,
    "avatar": avatar,
  };
}
