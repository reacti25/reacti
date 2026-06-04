import 'dart:convert';

/// Envelope returned by the Privacy Policy endpoint.
///
/// Wraps the API's standard `status`/`message` fields plus the [Data] payload
/// carrying the actual policy page content.
class PrivacyResponse {
  /// Whether the backend reported the request as successful.
  bool? status;

  /// Human-readable status or error message from the backend.
  String? message;

  /// The Privacy Policy page payload, or `null` when absent.
  Data? data;

  /// Creates a [PrivacyResponse] with optional [status], [message] and [data].
  PrivacyResponse({this.status, this.message, this.data});

  /// Returns a copy of this response with the given fields overridden.
  PrivacyResponse copyWith({bool? status, String? message, Data? data}) =>
      PrivacyResponse(
        status: status ?? this.status,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  /// Builds a [PrivacyResponse] from a raw JSON string [str].
  factory PrivacyResponse.fromRawJson(String str) =>
      PrivacyResponse.fromJson(json.decode(str));

  /// Serializes this response to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [PrivacyResponse] from a decoded JSON map [json].
  factory PrivacyResponse.fromJson(Map<String, dynamic> json) =>
      PrivacyResponse(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  /// Converts this response into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data?.toJson(),
  };
}

/// The Privacy Policy page record carried inside a [PrivacyResponse].
///
/// Mirrors a CMS page row: identity, title/slug, HTML body and publish state.
class Data {
  /// Database identifier of the page.
  int? id;

  /// Display title of the page.
  String? pageTitle;

  /// URL-friendly slug identifying the page.
  String? pageSlug;

  /// The page body as an HTML string rendered by the privacy screen.
  String? pageContent;

  /// Publish/visibility status of the page (e.g. `active`).
  String? status;

  /// Soft-delete timestamp; `null` when the page is not deleted.
  dynamic deletedAt;

  /// Creates a [Data] page record with all fields optional.
  Data({
    this.id,
    this.pageTitle,
    this.pageSlug,
    this.pageContent,
    this.status,
    this.deletedAt,
  });

  /// Returns a copy of this page with the given fields overridden.
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

  /// Builds a [Data] page from a raw JSON string [str].
  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  /// Serializes this page to a raw JSON string.
  String toRawJson() => json.encode(toJson());

  /// Builds a [Data] page from a decoded JSON map [json].
  factory Data.fromJson(Map<String, dynamic> json) => Data(
    id: json["id"],
    pageTitle: json["page_title"],
    pageSlug: json["page_slug"],
    pageContent: json["page_content"],
    status: json["status"],
    deletedAt: json["deleted_at"],
  );

  /// Converts this page into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    "id": id,
    "page_title": pageTitle,
    "page_slug": pageSlug,
    "page_content": pageContent,
    "status": status,
    "deleted_at": deletedAt,
  };
}
