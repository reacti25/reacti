import 'dart:convert';

class LoginResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  LoginResponse({this.success, this.message, this.data, this.code});

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

  factory LoginResponse.fromRawJson(String str) =>
      LoginResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
    code: json["code"],
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "code": code,
  };
}

class Data {
  int? id;
  String? firstName;
  String? lastName;
  dynamic username;
  String? email;
  String? role;
  dynamic avatar;
  String? token;
  DateTime? lastActivityAt;

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
  });

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
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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
  );

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
  };
}
