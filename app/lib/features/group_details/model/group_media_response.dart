import 'dart:convert';

/// Top-level envelope returned by the group-media endpoint.
///
/// Wraps the API's standard `success` / `message` / `code` metadata around
/// the [Data] payload that carries the paginated [Media] list.
class GroupMediaResponse {
  /// Whether the request succeeded server-side.
  bool? success;

  /// Human-readable status message from the server.
  String? message;

  /// The payload holding the media list and pagination info.
  Data? data;

  /// Application-level status code accompanying the response.
  int? code;

  /// Creates a [GroupMediaResponse] from optional named fields.
  GroupMediaResponse({this.success, this.message, this.data, this.code});

  /// Returns a copy of this response with the given fields overridden.
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

  /// Parses a [GroupMediaResponse] from a raw JSON [str].
  factory GroupMediaResponse.fromRawJson(String str) =>
      GroupMediaResponse.fromJson(json.decode(str));

  /// Serialises this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [GroupMediaResponse] from a decoded JSON map.
  factory GroupMediaResponse.fromJson(Map<String, dynamic> json) =>
      GroupMediaResponse(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        code: json["code"],
      );

  /// Serialises this response to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "code": code,
  };
}

/// Payload of [GroupMediaResponse] holding the media list and its pagination.
class Data {
  /// The page of shared media items.
  List<Media>? media;

  /// Pagination metadata describing the current and total pages.
  Pagination? pagination;

  /// Creates a [Data] payload from optional named fields.
  Data({this.media, this.pagination});

  /// Returns a copy of this payload with the given fields overridden.
  Data copyWith({List<Media>? media, Pagination? pagination}) => Data(
    media: media ?? this.media,
    pagination: pagination ?? this.pagination,
  );

  /// Parses a [Data] payload from a raw JSON [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serialises this payload to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Data] payload from a decoded JSON map.
  ///
  /// A missing `media` array is normalised to an empty list rather than
  /// `null` so callers can iterate without a null check.
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

  /// Serialises this payload to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "media":
        media == null ? [] : List<dynamic>.from(media!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

/// A single media item (image or video) shared in a group chat.
class Media {
  /// Unique identifier of the underlying message.
  int? id;

  /// URL of the media file.
  String? fileUrl;

  /// File type discriminator, e.g. `image` or `video`.
  String? fileType;

  /// ISO timestamp of when the media was sent.
  String? sentAt;

  /// The user who sent the media.
  Sender? sender;

  /// Creates a [Media] item from optional named fields.
  Media({this.id, this.fileUrl, this.fileType, this.sentAt, this.sender});

  /// Returns a copy of this media item with the given fields overridden.
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

  /// Parses a [Media] item from a raw JSON [str].
  factory Media.fromRawJson(String str) => Media.fromJson(json.decode(str));

  /// Serialises this media item to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Media] item from a decoded JSON map.
  factory Media.fromJson(Map<String, dynamic> json) => Media(
    id: json["id"],
    fileUrl: json["file_url"],
    fileType: json["file_type"],
    sentAt: json["sent_at"],
    sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
  );

  /// Serialises this media item to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "file_url": fileUrl,
    "file_type": fileType,
    "sent_at": sentAt,
    "sender": sender?.toJson(),
  };
}

/// Lightweight profile of the user who sent a [Media] item.
class Sender {
  /// Unique user identifier.
  int? id;

  /// Display name of the sender.
  String? name;

  /// Sender's avatar; left as `dynamic` because the API may omit it (`null`).
  dynamic avatar;

  /// Creates a [Sender] from optional named fields.
  Sender({this.id, this.name, this.avatar});

  /// Returns a copy of this sender with the given fields overridden.
  Sender copyWith({int? id, String? name, dynamic avatar}) => Sender(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
  );

  /// Parses a [Sender] from a raw JSON [str].
  factory Sender.fromRawJson(String str) => Sender.fromJson(json.decode(str));

  /// Serialises this sender to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Sender] from a decoded JSON map.
  factory Sender.fromJson(Map<String, dynamic> json) =>
      Sender(id: json["id"], name: json["name"], avatar: json["avatar"]);

  /// Serialises this sender to a JSON-encodable map.
  Map<String, dynamic> toJson() => {"id": id, "name": name, "avatar": avatar};
}

/// Pagination metadata describing the position within a paged result set.
class Pagination {
  /// Total number of items across all pages.
  int? total;

  /// Index of the page currently returned.
  int? currentPage;

  /// Index of the last available page.
  int? lastPage;

  /// Number of items per page.
  int? perPage;

  /// Creates a [Pagination] descriptor from optional named fields.
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

  /// Parses a [Pagination] descriptor from a raw JSON [str].
  factory Pagination.fromRawJson(String str) =>
      Pagination.fromJson(json.decode(str));

  /// Serialises this descriptor to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Parses a [Pagination] descriptor from a decoded JSON map.
  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    total: json["total"],
    currentPage: json["current_page"],
    lastPage: json["last_page"],
    perPage: json["per_page"],
  );

  /// Serialises this descriptor to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "total": total,
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
  };
}
