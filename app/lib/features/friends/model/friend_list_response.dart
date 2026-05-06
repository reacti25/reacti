import 'dart:convert';

class FriendListResponse {
  bool? success;
  String? message;
  List<Datum>? data;
  int? code;

  FriendListResponse({this.success, this.message, this.data, this.code});

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

  factory FriendListResponse.fromRawJson(String str) =>
      FriendListResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data":
        data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "code": code,
  };
}

class Datum {
  int? id;
  String? name;
  dynamic username;
  String? email;
  String? phone;
  String? avatar;

  Datum({
    this.id,
    this.name,
    this.username,
    this.email,
    this.phone,
    this.avatar,
  });

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

  factory Datum.fromRawJson(String str) => Datum.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    name: json["name"],
    username: json["username"],
    email: json["email"],
    phone: json["phone"],
    avatar: json["avatar"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "username": username,
    "email": email,
    "phone": phone,
    "avatar": avatar,
  };
}
