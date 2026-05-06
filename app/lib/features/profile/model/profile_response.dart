import 'dart:convert';

class ProfileResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  ProfileResponse({this.success, this.message, this.data, this.code});

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

  factory ProfileResponse.fromRawJson(String str) =>
      ProfileResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      ProfileResponse(
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
  String? fullName;
  String? firstName;
  String? lastName;
  String? username;
  String? email;
  dynamic bio;
  String? phone;
  String? avatar;
  int? totalFriends;
  int? totalGroups;
  String? createdAt;

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

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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
