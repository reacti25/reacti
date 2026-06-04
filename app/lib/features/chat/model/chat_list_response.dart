import 'dart:convert';

/// Top-level envelope for the chat-list endpoint (one-to-one and group
/// conversations the user participates in).
///
/// Mirrors the standard API response shape: a [success] flag, a human
/// [message], an HTTP-style [code], and the [data] payload holding the
/// conversations and pagination.
class ChatListResponse {
  /// Whether the request succeeded.
  bool? success;

  /// Human-readable status message returned by the API.
  String? message;

  /// Payload holding the chat list and its pagination metadata.
  Data? data;

  /// Numeric status code echoed by the API.
  int? code;

  /// Creates a [ChatListResponse]; all fields are optional.
  ChatListResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
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

  /// Parses a raw JSON [str] into a [ChatListResponse].
  factory ChatListResponse.fromRawJson(String str) =>
      ChatListResponse.fromJson(json.decode(str));

  /// Encodes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [ChatListResponse] from a decoded JSON [json] map.
  factory ChatListResponse.fromJson(Map<String, dynamic> json) =>
      ChatListResponse(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        code: json["code"],
      );

  /// Serializes this response back to a JSON map.
  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "code": code,
  };
}

/// Payload of [ChatListResponse]: the list of conversations plus pagination.
class Data {
  /// All conversations (one-to-one and group) on the current page.
  List<Chat>? chats;

  /// Pagination metadata describing the page window.
  Pagination? pagination;

  /// Creates a [Data] payload; both fields are optional.
  Data({this.chats, this.pagination});

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({List<Chat>? chats, Pagination? pagination}) => Data(
    chats: chats ?? this.chats,
    pagination: pagination ?? this.pagination,
  );

  /// Parses a raw JSON [str] into a [Data] payload.
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Encodes this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] payload from a decoded JSON [json] map; a missing
  /// `chats` key yields an empty list rather than null.
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

  /// Serializes this payload back to a JSON map.
  Map<String, dynamic> toJson() => {
    "chats":
        chats == null ? [] : List<dynamic>.from(chats!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

/// A single conversation row in the chat list.
///
/// Represents either a one-to-one chat or a group, distinguished by [type],
/// and carries the preview fields shown in the list (avatar, name, last
/// message and its timestamp).
class Chat {
  /// Conversation kind, e.g. `group` for group chats.
  String? type;

  /// Identifier of the conversation (peer user id or group id).
  int? id;

  /// Identifier of the chat room backing this conversation.
  int? roomId;

  /// Display name of the peer or group.
  String? name;

  /// Avatar image URL for the conversation.
  String? avatar;

  /// Text preview of the most recent message.
  String? lastMessage;

  /// Human-readable timestamp of the most recent message.
  String? lastMessageTime;

  /// Whether the conversation is currently active.
  bool? isActive;

  /// Number of members, relevant for group conversations.
  int? memberCount;

  /// Creates a [Chat] list row; all fields are optional.
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

  /// Returns a copy of this row with the given fields overridden.
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

  /// Parses a raw JSON [str] into a [Chat] row.
  factory Chat.fromRawJson(String str) => Chat.fromJson(json.decode(str));

  /// Encodes this row to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Chat] row from a decoded JSON [json] map.
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

  /// Serializes this row back to a JSON map.
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

/// Pagination metadata for a paged list response.
class Pagination {
  /// Total number of items across all pages.
  int? total;

  /// Index of the page currently returned.
  int? currentPage;

  /// Index of the last available page.
  int? lastPage;

  /// Number of items per page.
  int? perPage;

  /// Creates a [Pagination] descriptor; all fields are optional.
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

  /// Parses a raw JSON [str] into a [Pagination] descriptor.
  factory Pagination.fromRawJson(String str) =>
      Pagination.fromJson(json.decode(str));

  /// Encodes this descriptor to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Pagination] descriptor from a decoded JSON [json] map.
  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    total: json["total"],
    currentPage: json["current_page"],
    lastPage: json["last_page"],
    perPage: json["per_page"],
  );

  /// Serializes this descriptor back to a JSON map.
  Map<String, dynamic> toJson() => {
    "total": total,
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
  };
}
