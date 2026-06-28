import 'dart:convert';

/// Top-level envelope for the one-to-one inbox endpoint.
///
/// Wraps a [success] flag, a human [message], a numeric [code], and the
/// [data] payload holding the conversation participants, messages and
/// block state for a single chat thread.
class InboxResponse {
  /// Whether the request succeeded.
  bool? success;

  /// Human-readable status message returned by the API.
  String? message;

  /// Payload holding the conversation messages and metadata.
  Data? data;

  /// Numeric status code echoed by the API.
  int? code;

  /// Creates an [InboxResponse]; all fields are optional.
  InboxResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  InboxResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => InboxResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Parses a raw JSON [str] into an [InboxResponse].
  factory InboxResponse.fromRawJson(String str) =>
      InboxResponse.fromJson(json.decode(str));

  /// Encodes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds an [InboxResponse] from a decoded JSON [json] map.
  factory InboxResponse.fromJson(Map<String, dynamic> json) => InboxResponse(
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

/// Payload of [InboxResponse]: the participants, messages and block state
/// of a single one-to-one conversation.
class Data {
  /// The peer being chatted with.
  Receiver? receiver;

  /// The current user, as represented in this conversation.
  Receiver? sender;

  /// The chat room backing this conversation.
  DataRoom? room;

  /// Messages on the current page, oldest-to-newest as delivered by the API.
  List<Chat>? chat;

  /// Pagination metadata for the message list.
  Pagination? pagination;

  /// Whether the conversation is blocked in either direction.
  bool? isBlocked;

  /// Whether the current user is the one who issued the block.
  bool? blockByMe;

  /// Creates a [Data] payload; all fields are optional.
  Data({
    this.receiver,
    this.sender,
    this.room,
    this.chat,
    this.pagination,
    this.isBlocked,
    this.blockByMe,
  });

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({
    Receiver? receiver,
    Receiver? sender,
    DataRoom? room,
    List<Chat>? chat,
    Pagination? pagination,
    bool? isBlocked,
    bool? blockByMe,
  }) => Data(
    receiver: receiver ?? this.receiver,
    sender: sender ?? this.sender,
    room: room ?? this.room,
    chat: chat ?? this.chat,
    pagination: pagination ?? this.pagination,
    isBlocked: isBlocked ?? this.isBlocked,
    blockByMe: blockByMe ?? this.blockByMe,
  );

  /// Parses a raw JSON [str] into a [Data] payload.
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Encodes this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] payload from a decoded JSON [json] map; a missing
  /// `chat` key yields an empty list rather than null.
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    receiver:
        json["receiver"] == null ? null : Receiver.fromJson(json["receiver"]),
    sender: json["sender"] == null ? null : Receiver.fromJson(json["sender"]),
    room: json["room"] == null ? null : DataRoom.fromJson(json["room"]),
    chat:
        json["chat"] == null
            ? []
            : List<Chat>.from(json["chat"]!.map((x) => Chat.fromJson(x))),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
    isBlocked: json["is_blocked"],
    blockByMe: json["block_by_me"],
  );

  /// Serializes this payload back to a JSON map.
  Map<String, dynamic> toJson() => {
    "receiver": receiver?.toJson(),
    "sender": sender?.toJson(),
    "room": room?.toJson(),
    "chat":
        chat == null ? [] : List<dynamic>.from(chat!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
    "is_blocked": isBlocked,
    "blockByMe": blockByMe,
  };
}

/// A single message inside a one-to-one conversation.
///
/// Besides the server-side fields (id, text, file, status, blur/view state)
/// this model also carries client-only fields — [isLocal], [localPath] and
/// [uploadProgress] — used to render optimistically-inserted messages while
/// their upload is still in flight.
class Chat {
  /// Server identifier of the message; a large temporary value while local.
  int? id;

  /// Identifier of the user who sent the message.
  int? senderId;

  /// Identifier of the user who received the message.
  int? receiverId;

  /// Identifier of the chat room the message belongs to.
  int? roomId;

  /// Text body of the message.
  String? text;

  /// Attached media; loosely typed as the API may send a URL string or null.
  dynamic file;

  /// Delivery status of the message.
  String? status;

  /// Whether the attached media is blurred; loosely typed because the API
  /// may deliver it as `1`/`0`, a bool, or a string.
  dynamic isBlurred;

  /// Whether the message has been viewed by the recipient; loosely typed
  /// because the API delivers it as a bool (per the chat-conversation
  /// contract) while older backends sent `1`/`0`. Mirrors the group
  /// `Message` model, whose `isViewed` is likewise `dynamic`.
  dynamic isViewed;

  /// Server-side message classification.
  String? messageType;

  /// Whether the message was authored by the current user.
  bool? isMyText;

  /// Whether the UI should still present a blur overlay for the media.
  bool? shouldShowBlur;

  /// Human-readable timestamp; loosely typed to tolerate API variation.
  dynamic humanizeDate;

  /// Shortened preview of [text].
  String? shortText;

  /// Message kind, e.g. `reaction` for silent reaction recordings.
  String? type;

  /// Media kind of [file], e.g. `image`, `video`, `reaction`.
  String? mediaType;

  /// The quoted message, when this message is a reply.
  ReplyTo? replyTo;

  /// Author of the message.
  Receiver? sender;

  /// Recipient of the message.
  Receiver? receiver;

  /// The chat room the message belongs to.
  ChatRoom? room;

  /// Client-only flag: true while the message is an unsent optimistic entry.
  bool? isLocal;

  /// Client-only path to the local file being uploaded, used as a placeholder.
  String? localPath;

  /// Client-only upload progress in the range 0.0–1.0.
  double? uploadProgress;

  /// Typed view of the loose [isViewed] flag: whether the recipient has seen
  /// this message. Tolerates every shape the API has used — `true`, `1`,
  /// `"1"` — and treats anything else (including null/missing) as not seen.
  bool get isSeen => isViewed == true || isViewed == 1 || isViewed == '1';

  /// Creates a [Chat] message; [isLocal] defaults to false (a server message).
  Chat({
    this.id,
    this.senderId,
    this.receiverId,
    this.roomId,
    this.text,
    this.file,
    this.status,
    this.isBlurred,
    this.isViewed,
    this.messageType,
    this.isMyText,
    this.shouldShowBlur,
    this.humanizeDate,
    this.shortText,
    this.type,
    this.mediaType,
    this.replyTo,
    this.sender,
    this.receiver,
    this.room,
    this.isLocal = false,
    this.localPath,
    this.uploadProgress,
  });

  /// Returns a copy of this message with the given fields overridden.
  Chat copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    int? roomId,
    String? text,
    dynamic file,
    String? status,
    dynamic isBlurred,
    dynamic isViewed,
    String? messageType,
    bool? isMyText,
    bool? shouldShowBlur,
    dynamic humanizeDate,
    String? shortText,
    String? type,
    String? mediaType,
    ReplyTo? replyTo,
    Receiver? sender,
    Receiver? receiver,
    ChatRoom? room,
    bool? isLocal,
    String? localPath,
    double? uploadProgress,
  }) => Chat(
    id: id ?? this.id,
    senderId: senderId ?? this.senderId,
    receiverId: receiverId ?? this.receiverId,
    roomId: roomId ?? this.roomId,
    text: text ?? this.text,
    file: file ?? this.file,
    status: status ?? this.status,
    isBlurred: isBlurred ?? this.isBlurred,
    isViewed: isViewed ?? this.isViewed,
    messageType: messageType ?? this.messageType,
    isMyText: isMyText ?? this.isMyText,
    shouldShowBlur: shouldShowBlur ?? this.shouldShowBlur,
    humanizeDate: humanizeDate ?? this.humanizeDate,
    shortText: shortText ?? this.shortText,
    type: type ?? this.type,
    mediaType: mediaType ?? this.mediaType,
    replyTo: replyTo ?? this.replyTo,
    sender: sender ?? this.sender,
    receiver: receiver ?? this.receiver,
    room: room ?? this.room,
    isLocal: isLocal ?? this.isLocal,
    localPath: localPath ?? this.localPath,
    uploadProgress: uploadProgress ?? this.uploadProgress,
  );

  /// Parses a raw JSON [str] into a [Chat] message.
  factory Chat.fromRawJson(String str) => Chat.fromJson(json.decode(str));

  /// Encodes this message to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Chat] message from a decoded JSON [json] map; the client-only
  /// fields are reset since server payloads never carry them.
  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json["id"],
    senderId: json["sender_id"],
    receiverId: json["receiver_id"],
    roomId: json["room_id"],
    text: json["text"],
    file: json["file"],
    status: json["status"],
    isBlurred: json["is_blurred"],
    isViewed: json["is_viewed"],
    messageType: json["message_type"],
    isMyText: json["is_my_text"],
    shouldShowBlur: json["should_show_blur"],
    humanizeDate: json["humanize_date"],
    shortText: json["short_text"],
    type: json["type"],
    mediaType: json["media_type"],
    replyTo:
        json["reply_to"] == null ? null : ReplyTo.fromJson(json["reply_to"]),
    sender: json["sender"] == null ? null : Receiver.fromJson(json["sender"]),
    receiver:
        json["receiver"] == null ? null : Receiver.fromJson(json["receiver"]),
    room: json["room"] == null ? null : ChatRoom.fromJson(json["room"]),
    isLocal: false,
    localPath: null,
    uploadProgress: null,
  );

  /// Serializes this message back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "sender_id": senderId,
    "receiver_id": receiverId,
    "room_id": roomId,
    "text": text,
    "file": file,
    "status": status,
    "is_blurred": isBlurred,
    "is_viewed": isViewed,
    "message_type": messageType,
    "is_my_text": isMyText,
    "should_show_blur": shouldShowBlur,
    "humanize_date": humanizeDate,
    "short_text": shortText,
    "type": type,
    "media_type": mediaType,
    "reply_to": replyTo?.toJson(),
    "sender": sender?.toJson(),
    "receiver": receiver?.toJson(),
    "room": room?.toJson(),
    "isLocal": isLocal,
    "localPath": localPath,
    "uploadProgress": uploadProgress,
  };
}

/// Quoted-message model for a one-to-one [Chat] reply.
///
/// A trimmed copy of the original message — id, author, text and media —
/// used to render the quoted preview above the reply.
class ReplyTo {
  /// Identifier of the quoted original message.
  int? id;

  /// Identifier of the original message's author.
  int? senderId;

  /// Text body of the original message.
  String? text;

  /// Media attachment of the original message; loosely typed.
  dynamic file;

  /// Media kind of the original attachment.
  String? mediaType;

  /// Whether the original media is blurred; loosely typed to tolerate
  /// `1`/`0`, bool or string values from the API.
  dynamic isBlurred;

  /// Author of the original message.
  Receiver? sender;

  /// Creates a [ReplyTo]; all fields are optional.
  ReplyTo({
    this.id,
    this.senderId,
    this.text,
    this.file,
    this.mediaType,
    this.isBlurred,
    this.sender,
  });

  /// Returns a copy of this [ReplyTo] with the given fields overridden.
  ReplyTo copyWith({
    int? id,
    int? senderId,
    String? text,
    dynamic file,
    String? mediaType,
    dynamic isBlurred,
    Receiver? sender,
  }) => ReplyTo(
    id: id ?? this.id,
    senderId: senderId ?? this.senderId,
    text: text ?? this.text,
    file: file ?? this.file,
    mediaType: mediaType ?? this.mediaType,
    isBlurred: isBlurred ?? this.isBlurred,
    sender: sender ?? this.sender,
  );

  /// Parses a raw JSON [str] into a [ReplyTo].
  factory ReplyTo.fromRawJson(String str) => ReplyTo.fromJson(json.decode(str));

  /// Encodes this [ReplyTo] to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [ReplyTo] from a decoded JSON [json] map.
  factory ReplyTo.fromJson(Map<String, dynamic> json) => ReplyTo(
    id: json["id"],
    senderId: json["sender_id"],
    text: json["text"],
    file: json["file"],
    mediaType: json["media_type"],
    isBlurred: json["is_blurred"],
    sender: json["sender"] == null ? null : Receiver.fromJson(json["sender"]),
  );

  /// Serializes this [ReplyTo] back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "sender_id": senderId,
    "text": text,
    "file": file,
    "media_type": mediaType,
    "is_blurred": isBlurred,
    "sender": sender?.toJson(),
  };
}

/// A conversation participant (peer or current user) as returned by the
/// one-to-one inbox endpoint.
class Receiver {
  /// Identifier of the user.
  int? id;

  /// First name of the user.
  String? firstName;

  /// Last name of the user.
  String? lastName;

  /// Avatar image URL of the user.
  String? avatar;

  /// Timestamp of the user's last activity, used for presence display.
  DateTime? lastActivityAt;

  /// Creates a [Receiver]; all fields are optional.
  Receiver({
    this.id,
    this.firstName,
    this.lastName,
    this.avatar,
    this.lastActivityAt,
  });

  /// Returns a copy of this [Receiver] with the given fields overridden.
  Receiver copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? avatar,
    DateTime? lastActivityAt,
  }) => Receiver(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    avatar: avatar ?? this.avatar,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
  );

  /// Parses a raw JSON [str] into a [Receiver].
  factory Receiver.fromRawJson(String str) =>
      Receiver.fromJson(json.decode(str));

  /// Encodes this [Receiver] to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Receiver] from a decoded JSON [json] map; `last_activity_at`
  /// is parsed into a [DateTime] when present.
  factory Receiver.fromJson(Map<String, dynamic> json) => Receiver(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    avatar: json["avatar"],
    lastActivityAt:
        json["last_activity_at"] == null
            ? null
            : DateTime.parse(json["last_activity_at"]),
  );

  /// Serializes this [Receiver] back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "avatar": avatar,
    "last_activity_at": lastActivityAt?.toIso8601String(),
  };
}

/// Minimal chat-room descriptor embedded on a [Chat] message, identifying
/// the two users in the one-to-one room.
class ChatRoom {
  /// Identifier of the chat room.
  int? id;

  /// Identifier of the first participant.
  int? userOneId;

  /// Identifier of the second participant.
  int? userTwoId;

  /// Creates a [ChatRoom]; all fields are optional.
  ChatRoom({this.id, this.userOneId, this.userTwoId});

  /// Returns a copy of this [ChatRoom] with the given fields overridden.
  ChatRoom copyWith({int? id, int? userOneId, int? userTwoId}) => ChatRoom(
    id: id ?? this.id,
    userOneId: userOneId ?? this.userOneId,
    userTwoId: userTwoId ?? this.userTwoId,
  );

  /// Parses a raw JSON [str] into a [ChatRoom].
  factory ChatRoom.fromRawJson(String str) =>
      ChatRoom.fromJson(json.decode(str));

  /// Encodes this [ChatRoom] to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [ChatRoom] from a decoded JSON [json] map.
  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json["id"],
    userOneId: json["user_one_id"],
    userTwoId: json["user_two_id"],
  );

  /// Serializes this [ChatRoom] back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "user_one_id": userOneId,
    "user_two_id": userTwoId,
  };
}

/// Pagination metadata for the inbox message list.
class Pagination {
  /// Total number of messages across all pages.
  int? total;

  /// Index of the page currently returned.
  int? currentPage;

  /// Index of the last available page.
  int? lastPage;

  /// Number of messages per page.
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

/// Full chat-room descriptor for the conversation, including timestamps.
///
/// Distinct from [ChatRoom]: this is the top-level `room` of the inbox
/// payload and additionally carries [createdAt] / [updatedAt].
class DataRoom {
  /// Identifier of the chat room.
  int? id;

  /// Identifier of the first participant.
  int? userOneId;

  /// Identifier of the second participant.
  int? userTwoId;

  /// When the room was created.
  DateTime? createdAt;

  /// When the room was last updated.
  DateTime? updatedAt;

  /// Creates a [DataRoom]; all fields are optional.
  DataRoom({
    this.id,
    this.userOneId,
    this.userTwoId,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns a copy of this [DataRoom] with the given fields overridden.
  DataRoom copyWith({
    int? id,
    int? userOneId,
    int? userTwoId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DataRoom(
    id: id ?? this.id,
    userOneId: userOneId ?? this.userOneId,
    userTwoId: userTwoId ?? this.userTwoId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Parses a raw JSON [str] into a [DataRoom].
  factory DataRoom.fromRawJson(String str) =>
      DataRoom.fromJson(json.decode(str));

  /// Encodes this [DataRoom] to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [DataRoom] from a decoded JSON [json] map; timestamps are
  /// parsed into [DateTime] values when present.
  factory DataRoom.fromJson(Map<String, dynamic> json) => DataRoom(
    id: json["id"],
    userOneId: json["user_one_id"],
    userTwoId: json["user_two_id"],
    createdAt:
        json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt:
        json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
  );

  /// Serializes this [DataRoom] back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "user_one_id": userOneId,
    "user_two_id": userTwoId,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}
