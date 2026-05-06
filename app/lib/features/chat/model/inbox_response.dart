import 'dart:convert';

class InboxResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  InboxResponse({this.success, this.message, this.data, this.code});

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

  factory InboxResponse.fromRawJson(String str) =>
      InboxResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory InboxResponse.fromJson(Map<String, dynamic> json) => InboxResponse(
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
  Receiver? receiver;
  Receiver? sender;
  DataRoom? room;
  List<Chat>? chat;
  Pagination? pagination;
  bool? isBlocked;
  bool? blockByMe;

  Data({
    this.receiver,
    this.sender,
    this.room,
    this.chat,
    this.pagination,
    this.isBlocked,
    this.blockByMe,
  });

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

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

class Chat {
  int? id;
  int? senderId;
  int? receiverId;
  int? roomId;
  String? text;
  dynamic file;
  String? status;
  dynamic isBlurred;
  int? isViewed;
  String? messageType;
  bool? isMyText;
  bool? shouldShowBlur;
  dynamic humanizeDate;
  String? shortText;
  String? type;
  String? mediaType;
  ReplyTo? replyTo;
  Receiver? sender;
  Receiver? receiver;
  ChatRoom? room;
  bool? isLocal;
  String? localPath;
  double? uploadProgress;

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

  Chat copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    int? roomId,
    String? text,
    dynamic file,
    String? status,
    dynamic isBlurred,
    int? isViewed,
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

  factory Chat.fromRawJson(String str) => Chat.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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
    replyTo: json["reply_to"] == null ? null : ReplyTo.fromJson(json["reply_to"]),
    sender: json["sender"] == null ? null : Receiver.fromJson(json["sender"]),
    receiver:
        json["receiver"] == null ? null : Receiver.fromJson(json["receiver"]),
    room: json["room"] == null ? null : ChatRoom.fromJson(json["room"]),
    isLocal: false,
    localPath: null,
    uploadProgress: null,
  );

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

class ReplyTo {
  int? id;
  int? senderId;
  String? text;
  dynamic file;
  String? mediaType;
  dynamic isBlurred;
  Receiver? sender;

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

  factory ReplyTo.fromRawJson(String str) => ReplyTo.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ReplyTo.fromJson(Map<String, dynamic> json) => ReplyTo(
    id: json["id"],
    senderId: json["sender_id"],
    text: json["text"],
    file: json["file"],
    mediaType: json["media_type"],
    isBlurred: json["is_blurred"],
    sender: json["sender"] == null ? null : Receiver.fromJson(json["sender"]),
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

class Receiver {
  int? id;
  String? firstName;
  String? lastName;
  String? avatar;
  DateTime? lastActivityAt;

  Receiver({
    this.id,
    this.firstName,
    this.lastName,
    this.avatar,
    this.lastActivityAt,
  });

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

  factory Receiver.fromRawJson(String str) =>
      Receiver.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

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

  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "avatar": avatar,
    "last_activity_at": lastActivityAt?.toIso8601String(),
  };
}

class ChatRoom {
  int? id;
  int? userOneId;
  int? userTwoId;

  ChatRoom({this.id, this.userOneId, this.userTwoId});

  ChatRoom copyWith({int? id, int? userOneId, int? userTwoId}) => ChatRoom(
    id: id ?? this.id,
    userOneId: userOneId ?? this.userOneId,
    userTwoId: userTwoId ?? this.userTwoId,
  );

  factory ChatRoom.fromRawJson(String str) =>
      ChatRoom.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json["id"],
    userOneId: json["user_one_id"],
    userTwoId: json["user_two_id"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_one_id": userOneId,
    "user_two_id": userTwoId,
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

class DataRoom {
  int? id;
  int? userOneId;
  int? userTwoId;
  DateTime? createdAt;
  DateTime? updatedAt;

  DataRoom({
    this.id,
    this.userOneId,
    this.userTwoId,
    this.createdAt,
    this.updatedAt,
  });

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

  factory DataRoom.fromRawJson(String str) =>
      DataRoom.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DataRoom.fromJson(Map<String, dynamic> json) => DataRoom(
    id: json["id"],
    userOneId: json["user_one_id"],
    userTwoId: json["user_two_id"],
    createdAt:
        json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt:
        json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_one_id": userOneId,
    "user_two_id": userTwoId,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
  };
}
