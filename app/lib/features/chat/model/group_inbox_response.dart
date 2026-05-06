import 'dart:convert';

class GroupInboxResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  GroupInboxResponse({this.success, this.message, this.data, this.code});

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

  factory GroupInboxResponse.fromRawJson(String str) =>
      GroupInboxResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GroupInboxResponse.fromJson(Map<String, dynamic> json) =>
      GroupInboxResponse(
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
  List<Message>? messages;
  Pagination? pagination;

  Data({this.messages, this.pagination});

  Data copyWith({List<Message>? messages, Pagination? pagination}) => Data(
    messages: messages ?? this.messages,
    pagination: pagination ?? this.pagination,
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

  Map<String, dynamic> toJson() => {
    "messages":
        messages == null
            ? []
            : List<dynamic>.from(messages!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class Message {
  int? id;
  int? groupId;
  int? senderId;
  String? text;
  String? file;
  String? status;
  dynamic isBlurred;
  dynamic isViewed;
  String? messageType;
  String? createdAt;
  String? mediaType;
  Sender? sender;
  Group? group;
  ReplyTo? replyTo;
  bool? isLocal;
  String? localPath;
  double? uploadProgress;

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

  factory Message.fromRawJson(String str) => Message.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

class Group {
  int? id;
  String? name;
  String? avatar;

  Group({this.id, this.name, this.avatar});

  Group copyWith({int? id, String? name, String? avatar}) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
  );

  factory Group.fromRawJson(String str) => Group.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Group.fromJson(Map<String, dynamic> json) =>
      Group(id: json["id"], name: json["name"], avatar: json["avatar"]);

  Map<String, dynamic> toJson() => {"id": id, "name": name, "avatar": avatar};
}

class Sender {
  int? id;
  String? firstName;
  String? lastName;
  String? avatar;

  Sender({this.id, this.firstName, this.lastName, this.avatar});

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

  factory Sender.fromRawJson(String str) => Sender.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Sender.fromJson(Map<String, dynamic> json) => Sender(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    avatar: json["avatar"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
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

class ReplyTo {
  int? id;
  int? senderId;
  String? text;
  String? file;
  String? mediaType;
  dynamic isBlurred;
  Sender? sender;

  ReplyTo({
    this.id,
    this.senderId,
    this.text,
    this.file,
    this.mediaType,
    this.isBlurred,
    this.sender,
  });

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

  factory ReplyTo.fromRawJson(String str) => ReplyTo.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ReplyTo.fromJson(Map<String, dynamic> json) => ReplyTo(
    id: json["id"],
    senderId: json["sender_id"],
    text: json["text"],
    file: json["file"],
    mediaType: json["media_type"],
    isBlurred: json["is_blurred"],
    sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
  );

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
