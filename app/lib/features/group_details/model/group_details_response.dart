import 'dart:convert';

class GroupDetailsResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  GroupDetailsResponse({this.success, this.message, this.data, this.code});

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

  factory GroupDetailsResponse.fromRawJson(String str) =>
      GroupDetailsResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GroupDetailsResponse.fromJson(Map<String, dynamic> json) =>
      GroupDetailsResponse(
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
  Group? group;

  Data({this.group});

  Data copyWith({Group? group}) => Data(group: group ?? this.group);

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) =>
      Data(group: json["group"] == null ? null : Group.fromJson(json["group"]));

  Map<String, dynamic> toJson() => {"group": group?.toJson()};
}

class Group {
  int? id;
  String? name;
  String? description;
  String? avatar;
  bool? isAdmin;
  int? memberCount;
  String? createdAt;
  String? updatedAt;
  Creator? creator;
  List<Member>? members;

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

  factory Group.fromRawJson(String str) => Group.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

class Creator {
  int? id;
  String? firstName;
  String? lastName;
  String? email;
  String? avatar;
  String? lastActivityAt;

  Creator({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.avatar,
    this.lastActivityAt,
  });

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

  factory Creator.fromRawJson(String str) => Creator.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    email: json["email"],
    avatar: json["avatar"],
    lastActivityAt: json["last_activity_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "email": email,
    "avatar": avatar,
    "last_activity_at": lastActivityAt,
  };
}

class Member {
  int? id;
  String? role;
  String? joinedAt;
  Creator? user;

  Member({this.id, this.role, this.joinedAt, this.user});

  Member copyWith({int? id, String? role, String? joinedAt, Creator? user}) =>
      Member(
        id: id ?? this.id,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
        user: user ?? this.user,
      );

  factory Member.fromRawJson(String str) => Member.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json["id"],
    role: json["role"],
    joinedAt: json["joined_at"],
    user: json["user"] == null ? null : Creator.fromJson(json["user"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "role": role,
    "joined_at": joinedAt,
    "user": user?.toJson(),
  };
}
