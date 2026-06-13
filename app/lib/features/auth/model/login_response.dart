import 'dart:convert';

/// Envelope returned by the login and signup-OTP-verification endpoints.
///
/// Carries the request outcome ([success]/[code]/[message]) plus the
/// authenticated user payload in [data].
class LoginResponse {
  /// Whether the backend reported the request as successful.
  bool? success;

  /// Human-readable status message from the backend.
  String? message;

  /// The authenticated user payload, or `null` when the request failed.
  Data? data;

  /// Numeric status/result code from the backend.
  int? code;

  /// Creates a [LoginResponse] from its individual fields.
  LoginResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  LoginResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => LoginResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Parses a [LoginResponse] from a raw JSON [str].
  factory LoginResponse.fromRawJson(String str) =>
      LoginResponse.fromJson(json.decode(str));

  /// Serializes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [LoginResponse] from a decoded JSON map.
  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
    code: json["code"],
  );

  /// Serializes this response to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "code": code,
  };
}

/// Authenticated user payload nested inside a [LoginResponse].
///
/// Holds the user's profile fields and, crucially, the session [token] used to
/// authenticate subsequent API requests.
class Data {
  /// Unique user identifier.
  int? id;

  /// User's first name.
  String? firstName;

  /// User's last name.
  String? lastName;

  /// User's username; `dynamic` because the backend may return `null`.
  dynamic username;

  /// User's email address.
  String? email;

  /// User's role/permission tier.
  String? role;

  /// User's avatar; `dynamic` because the backend may return `null`.
  dynamic avatar;

  /// Session/auth token granted on successful authentication.
  String? token;

  /// Timestamp of the user's last recorded activity.
  DateTime? lastActivityAt;

  /// When the user consented to silent reaction-recording (DG1); `null` when
  /// they have not consented. The server is the source of truth for this.
  DateTime? recordingConsentAt;

  /// Creates a [Data] payload from its individual fields.
  Data({
    this.id,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.role,
    this.avatar,
    this.token,
    this.lastActivityAt,
    this.recordingConsentAt,
  });

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({
    int? id,
    String? firstName,
    String? lastName,
    dynamic username,
    String? email,
    String? role,
    dynamic avatar,
    String? token,
    DateTime? lastActivityAt,
    DateTime? recordingConsentAt,
  }) => Data(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    username: username ?? this.username,
    email: email ?? this.email,
    role: role ?? this.role,
    avatar: avatar ?? this.avatar,
    token: token ?? this.token,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    recordingConsentAt: recordingConsentAt ?? this.recordingConsentAt,
  );

  /// Parses a [Data] payload from a raw JSON [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serializes this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] payload from a decoded JSON map.
  ///
  /// `last_activity_at` is parsed into a [DateTime] when present, otherwise
  /// left `null`.
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    username: json["username"],
    email: json["email"],
    role: json["role"],
    avatar: json["avatar"],
    token: json["token"],
    lastActivityAt:
        json["last_activity_at"] == null
            ? null
            : DateTime.parse(json["last_activity_at"]),
    recordingConsentAt:
        json["recording_consent_at"] == null
            ? null
            : DateTime.parse(json["recording_consent_at"]),
  );

  /// Serializes this payload to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "username": username,
    "email": email,
    "role": role,
    "avatar": avatar,
    "token": token,
    "last_activity_at": lastActivityAt?.toIso8601String(),
    "recording_consent_at": recordingConsentAt?.toIso8601String(),
  };
}
