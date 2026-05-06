import 'dart:convert';

class GroupMediaResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  GroupMediaResponse({this.success, this.message, this.data, this.code});

  GroupMediaResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => GroupMediaResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  factory GroupMediaResponse.fromRawJson(String str) =>
      GroupMediaResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GroupMediaResponse.fromJson(Map<String, dynamic> json) =>
      GroupMediaResponse(
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
  List<Media>? media;
  Pagination? pagination;

  Data({this.media, this.pagination});

  Data copyWith({List<Media>? media, Pagination? pagination}) => Data(
    media: media ?? this.media,
    pagination: pagination ?? this.pagination,
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    media:
        json["media"] == null
            ? []
            : List<Media>.from(json["media"]!.map((x) => Media.fromJson(x))),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "media":
        media == null ? [] : List<dynamic>.from(media!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class Media {
  int? id;
  String? fileUrl;
  String? fileType;
  String? sentAt;
  Sender? sender;

  Media({this.id, this.fileUrl, this.fileType, this.sentAt, this.sender});

  Media copyWith({
    int? id,
    String? fileUrl,
    String? fileType,
    String? sentAt,
    Sender? sender,
  }) => Media(
    id: id ?? this.id,
    fileUrl: fileUrl ?? this.fileUrl,
    fileType: fileType ?? this.fileType,
    sentAt: sentAt ?? this.sentAt,
    sender: sender ?? this.sender,
  );

  factory Media.fromRawJson(String str) => Media.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Media.fromJson(Map<String, dynamic> json) => Media(
    id: json["id"],
    fileUrl: json["file_url"],
    fileType: json["file_type"],
    sentAt: json["sent_at"],
    sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "file_url": fileUrl,
    "file_type": fileType,
    "sent_at": sentAt,
    "sender": sender?.toJson(),
  };
}

class Sender {
  int? id;
  String? name;
  dynamic avatar;

  Sender({this.id, this.name, this.avatar});

  Sender copyWith({int? id, String? name, dynamic avatar}) => Sender(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
  );

  factory Sender.fromRawJson(String str) => Sender.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Sender.fromJson(Map<String, dynamic> json) =>
      Sender(id: json["id"], name: json["name"], avatar: json["avatar"]);

  Map<String, dynamic> toJson() => {"id": id, "name": name, "avatar": avatar};
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
