import 'dart:convert';

/// Top-level envelope for the group-conversation inbox endpoint.
///
/// Wraps a [success] flag, a human [message], a numeric [code], and the
/// [data] payload holding the group's messages and pagination.
class GroupInboxResponse {
  /// Whether the request succeeded.
  bool? success;

  /// Human-readable status message returned by the API.
  String? message;

  /// Payload holding the group messages and pagination metadata.
  Data? data;

  /// Numeric status code echoed by the API.
  int? code;

  /// Creates a [GroupInboxResponse]; all fields are optional.
  GroupInboxResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
  GroupInboxResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => GroupInboxResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  /// Parses a raw JSON [str] into a [GroupInboxResponse].
  factory GroupInboxResponse.fromRawJson(String str) =>
      GroupInboxResponse.fromJson(json.decode(str));

  /// Encodes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [GroupInboxResponse] from a decoded JSON [json] map.
  factory GroupInboxResponse.fromJson(Map<String, dynamic> json) =>
      GroupInboxResponse(
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

/// Payload of [GroupInboxResponse]: the group messages plus pagination.
class Data {
  /// Group messages on the current page.
  List<Message>? messages;

  /// Pagination metadata for the message list.
  Pagination? pagination;

  /// Creates a [Data] payload; both fields are optional.
  Data({this.messages, this.pagination});

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({List<Message>? messages, Pagination? pagination}) => Data(
    messages: messages ?? this.messages,
    pagination: pagination ?? this.pagination,
  );

  /// Parses a raw JSON [str] into a [Data] payload.
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Encodes this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] payload from a decoded JSON [json] map; a missing
  /// `messages` key yields an empty list rather than null.
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    messages:
        json["messages"] == null
            ? []
            : List<Message>.from(
              json["messages"]!.map((x) => Message.fromJson(x)),
            ),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  /// Serializes this payload back to a JSON map.
  Map<String, dynamic> toJson() => {
    "messages":
        messages == null
            ? []
            : List<dynamic>.from(messages!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

/// A single message inside a group conversation.
///
/// Carries server fields (id, sender, group, text, file, blur/view state)
/// plus client-only fields — [isLocal], [localPath], [uploadProgress] —
/// used to render optimistically-inserted messages and reaction uploads
/// while their upload is still in flight.
class Message {
  /// Server identifier of the message; a large temporary value while local.
  int? id;

  /// Identifier of the group the message belongs to.
  int? groupId;

  /// Identifier of the user who sent the message.
  int? senderId;

  /// Text body of the message.
  String? text;

  /// URL of the attached media file, if any.
  String? file;

  /// Delivery status of the message.
  String? status;

  /// Whether the attached media is blurred; loosely typed to tolerate
  /// `1`/`0`, bool or string values from the API.
  dynamic isBlurred;

  /// Whether the message has been viewed; loosely typed for the same reason.
  dynamic isViewed;

  /// Message kind, e.g. `normal` or `reaction`.
  String? messageType;

  /// Human-readable creation timestamp.
  String? createdAt;

  /// Media kind of [file], e.g. `image`, `video`, `reaction`.
  String? mediaType;

  /// Author of the message.
  Sender? sender;

  /// The group the message was sent to.
  Group? group;

  /// The quoted message, when this message is a reply.
  ReplyTo? replyTo;

  /// Client-only flag: true while the message is an unsent optimistic entry.
  bool? isLocal;

  /// Client-only path to the local file being uploaded, used as a placeholder.
  String? localPath;

  /// Client-only upload progress in the range 0.0–1.0.
  double? uploadProgress;

  /// Creates a [Message]; [isLocal] defaults to false (a server message).
  Message({
    this.id,
    this.groupId,
    this.senderId,
    this.text,
    this.file,
    this.status,
    this.isBlurred,
    this.isViewed,
    this.messageType,
    this.createdAt,
    this.mediaType,
    this.sender,
    this.group,
    this.replyTo,
    this.isLocal = false,
    this.localPath,
    this.uploadProgress,
  });

  /// Returns a copy of this message with the given fields overridden.
  Message copyWith({
    int? id,
    int? groupId,
    int? senderId,
    String? text,
    String? file,
    String? status,
    dynamic isBlurred,
    dynamic isViewed,
    String? messageType,
    String? createdAt,
    String? mediaType,
    Sender? sender,
    Group? group,
    ReplyTo? replyTo,
    bool? isLocal,
    String? localPath,
    double? uploadProgress,
  }) => Message(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    senderId: senderId ?? this.senderId,
    text: text ?? this.text,
    file: file ?? this.file,
    status: status ?? this.status,
    isBlurred: isBlurred ?? this.isBlurred,
    isViewed: isViewed ?? this.isViewed,
    messageType: messageType ?? this.messageType,
    createdAt: createdAt ?? this.createdAt,
    mediaType: mediaType ?? this.mediaType,
    sender: sender ?? this.sender,
    group: group ?? this.group,
    replyTo: replyTo ?? this.replyTo,
    isLocal: isLocal ?? this.isLocal,
    localPath: localPath ?? this.localPath,
    uploadProgress: uploadProgress ?? this.uploadProgress,
  );

  /// Parses a raw JSON [str] into a [Message].
  factory Message.fromRawJson(String str) => Message.fromJson(json.decode(str));

  /// Encodes this message to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Message] from a decoded JSON [json] map; the client-only
  /// fields are reset since server payloads never carry them.
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json["id"],
    groupId: json["group_id"],
    senderId: json["sender_id"],
    text: json["text"],
    file: json["file"],
    status: json["status"],
    isBlurred: json["is_blurred"],
    isViewed: json["is_viewed"],
    messageType: json["message_type"],
    createdAt: json["created_at"],
    mediaType: json["media_type"],
    sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
    group: json["group"] == null ? null : Group.fromJson(json["group"]),
    replyTo: json["reply_to"] == null ? null : ReplyTo.fromJson(json["reply_to"]),
    isLocal: false,
    localPath: null,
    uploadProgress: null,
  );

  /// Serializes this message back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "group_id": groupId,
    "sender_id": senderId,
    "text": text,
    "file": file,
    "status": status,
    "is_blurred": isBlurred,
    "is_viewed": isViewed,
    "message_type": messageType,
    "created_at": createdAt,
    "media_type": mediaType,
    "sender": sender?.toJson(),
    "group": group?.toJson(),
    "reply_to": replyTo?.toJson(),
    "isLocal": isLocal,
    "local_path": localPath,
    "upload_progress": uploadProgress,
  };
}

/// Minimal group descriptor embedded on a [Message].
class Group {
  /// Identifier of the group.
  int? id;

  /// Display name of the group.
  String? name;

  /// Avatar image URL of the group.
  String? avatar;

  /// Creates a [Group]; all fields are optional.
  Group({this.id, this.name, this.avatar});

  /// Returns a copy of this [Group] with the given fields overridden.
  Group copyWith({int? id, String? name, String? avatar}) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
  );

  /// Parses a raw JSON [str] into a [Group].
  factory Group.fromRawJson(String str) => Group.fromJson(json.decode(str));

  /// Encodes this [Group] to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Group] from a decoded JSON [json] map.
  factory Group.fromJson(Map<String, dynamic> json) =>
      Group(id: json["id"], name: json["name"], avatar: json["avatar"]);

  /// Serializes this [Group] back to a JSON map.
  Map<String, dynamic> toJson() => {"id": id, "name": name, "avatar": avatar};
}

/// Author of a group [Message]; a trimmed user profile.
class Sender {
  /// Identifier of the user.
  int? id;

  /// First name of the user.
  String? firstName;

  /// Last name of the user.
  String? lastName;

  /// Avatar image URL of the user.
  String? avatar;

  /// Creates a [Sender]; all fields are optional.
  Sender({this.id, this.firstName, this.lastName, this.avatar});

  /// Returns a copy of this [Sender] with the given fields overridden.
  Sender copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? avatar,
  }) => Sender(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    avatar: avatar ?? this.avatar,
  );

  /// Parses a raw JSON [str] into a [Sender].
  factory Sender.fromRawJson(String str) => Sender.fromJson(json.decode(str));

  /// Encodes this [Sender] to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Sender] from a decoded JSON [json] map.
  factory Sender.fromJson(Map<String, dynamic> json) => Sender(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    avatar: json["avatar"],
  );

  /// Serializes this [Sender] back to a JSON map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "avatar": avatar,
  };
}

/// Pagination metadata for the group message list.
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

/// Quoted-message model for a group [Message] reply.
///
/// A trimmed copy of the original group message used to render the quoted
/// preview above the reply.
class ReplyTo {
  /// Identifier of the quoted original message.
  int? id;

  /// Identifier of the original message's author.
  int? senderId;

  /// Text body of the original message.
  String? text;

  /// URL of the original message's media attachment.
  String? file;

  /// Media kind of the original attachment.
  String? mediaType;

  /// Whether the original media is blurred; loosely typed to tolerate
  /// `1`/`0`, bool or string values from the API.
  dynamic isBlurred;

  /// Author of the original message.
  Sender? sender;

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
    String? file,
    String? mediaType,
    dynamic isBlurred,
    Sender? sender,
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
    sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
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
