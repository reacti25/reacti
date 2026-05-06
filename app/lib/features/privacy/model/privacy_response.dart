import 'dart:convert';

class PrivacyResponse {
  bool? status;
  String? message;
  Data? data;

  PrivacyResponse({this.status, this.message, this.data});

  PrivacyResponse copyWith({bool? status, String? message, Data? data}) =>
      PrivacyResponse(
        status: status ?? this.status,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory PrivacyResponse.fromRawJson(String str) =>
      PrivacyResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PrivacyResponse.fromJson(Map<String, dynamic> json) =>
      PrivacyResponse(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data?.toJson(),
  };
}

class Data {
  int? id;
  String? pageTitle;
  String? pageSlug;
  String? pageContent;
  String? status;
  dynamic deletedAt;

  Data({
    this.id,
    this.pageTitle,
    this.pageSlug,
    this.pageContent,
    this.status,
    this.deletedAt,
  });

  Data copyWith({
    int? id,
    String? pageTitle,
    String? pageSlug,
    String? pageContent,
    String? status,
    dynamic deletedAt,
  }) => Data(
    id: id ?? this.id,
    pageTitle: pageTitle ?? this.pageTitle,
    pageSlug: pageSlug ?? this.pageSlug,
    pageContent: pageContent ?? this.pageContent,
    status: status ?? this.status,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    id: json["id"],
    pageTitle: json["page_title"],
    pageSlug: json["page_slug"],
    pageContent: json["page_content"],
    status: json["status"],
    deletedAt: json["deleted_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "page_title": pageTitle,
    "page_slug": pageSlug,
    "page_content": pageContent,
    "status": status,
    "deleted_at": deletedAt,
  };
}
