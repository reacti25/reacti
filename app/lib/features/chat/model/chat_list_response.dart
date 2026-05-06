import 'dart:convert';

class ChatListResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  ChatListResponse({this.success, this.message, this.data, this.code});

  ChatListResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => ChatListResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  factory ChatListResponse.fromRawJson(String str) =>
      ChatListResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ChatListResponse.fromJson(Map<String, dynamic> json) =>
      ChatListResponse(
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
  List<Chat>? chats;
  Pagination? pagination;

  Data({this.chats, this.pagination});

  Data copyWith({List<Chat>? chats, Pagination? pagination}) => Data(
    chats: chats ?? this.chats,
    pagination: pagination ?? this.pagination,
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    chats:
        json["chats"] == null
            ? []
            : List<Chat>.from(json["chats"]!.map((x) => Chat.fromJson(x))),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "chats":
        chats == null ? [] : List<dynamic>.from(chats!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class Chat {
  String? type;
  int? id;
  int? roomId;
  String? name;
  String? avatar;
  String? lastMessage;
  String? lastMessageTime;
  bool? isActive;
  int? memberCount;

  Chat({
    this.type,
    this.id,
    this.roomId,
    this.name,
    this.avatar,
    this.lastMessage,
    this.lastMessageTime,
    this.isActive,
    this.memberCount,
  });

  Chat copyWith({
    String? type,
    int? id,
    int? roomId,
    String? name,
    String? avatar,
    String? lastMessage,
    String? lastMessageTime,
    bool? isActive,
    int? memberCount,
  }) => Chat(
    type: type ?? this.type,
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    isActive: isActive ?? this.isActive,
    memberCount: memberCount ?? this.memberCount,
  );

  factory Chat.fromRawJson(String str) => Chat.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    type: json["type"],
    id: json["id"],
    roomId: json["room_id"],
    name: json["name"],
    avatar: json["avatar"],
    lastMessage: json["last_message"],
    lastMessageTime: json["last_message_time"],
    isActive: json["is_active"],
    memberCount: json["member_count"],
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "id": id,
    "room_id": roomId,
    "name": name,
    "avatar": avatar,
    "last_message": lastMessage,
    "last_message_time": lastMessageTime,
    "is_active": isActive,
    "member_count": memberCount,
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
