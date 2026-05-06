import 'dart:convert';

class BlockListResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  BlockListResponse({this.success, this.message, this.data, this.code});

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

  factory BlockListResponse.fromRawJson(String str) =>
      BlockListResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BlockListResponse.fromJson(Map<String, dynamic> json) =>
      BlockListResponse(
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
  List<BlockedUserElement>? blockedUsers;
  Pagination? pagination;

  Data({this.blockedUsers, this.pagination});

  Data copyWith({
    List<BlockedUserElement>? blockedUsers,
    Pagination? pagination,
  }) => Data(
    blockedUsers: blockedUsers ?? this.blockedUsers,
    pagination: pagination ?? this.pagination,
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

  Map<String, dynamic> toJson() => {
    "blocked_users":
        blockedUsers == null
            ? []
            : List<dynamic>.from(blockedUsers!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class BlockedUserElement {
  int? id;
  int? blockUserId;
  String? createdAt;
  BlockedUserBlockedUser? blockedUser;

  BlockedUserElement({
    this.id,
    this.blockUserId,
    this.createdAt,
    this.blockedUser,
  });

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

  factory BlockedUserElement.fromRawJson(String str) =>
      BlockedUserElement.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

  Map<String, dynamic> toJson() => {
    "id": id,
    "block_user_id": blockUserId,
    "created_at": createdAt,
    "blocked_user": blockedUser?.toJson(),
  };
}

class BlockedUserBlockedUser {
  int? id;
  String? fullName;
  String? firstName;
  String? lastName;
  String? username;
  String? avatar;

  BlockedUserBlockedUser({
    this.id,
    this.fullName,
    this.firstName,
    this.lastName,
    this.username,
    this.avatar,
  });

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

  factory BlockedUserBlockedUser.fromRawJson(String str) =>
      BlockedUserBlockedUser.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BlockedUserBlockedUser.fromJson(Map<String, dynamic> json) =>
      BlockedUserBlockedUser(
        id: json["id"],
        fullName: json["full_name"],
        firstName: json["first_name"],
        lastName: json["last_name"],
        username: json["username"],
        avatar: json["avatar"],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "full_name": fullName,
    "first_name": firstName,
    "last_name": lastName,
    "username": username,
    "avatar": avatar,
  };
}

class Pagination {
  int? total;
  int? currentPage;
  int? lastPage;
  int? perPage;

  Pagination({this.total, this.currentPage, this.lastPage, this.perPage});

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

  factory Pagination.fromRawJson(String str) =>
      Pagination.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    total: json["total"],
    currentPage: json["current_page"],
    lastPage: json["last_page"],
    perPage: json["per_page"],
  );

  Map<String, dynamic> toJson() => {
    "total": total,
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
  };
}
