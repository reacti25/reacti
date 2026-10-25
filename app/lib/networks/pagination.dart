import 'dart:convert';

/// Page metadata the backend attaches to every paginated list.
///
/// One shared class for all list responses (it used to be copied into seven
/// model files). Every field is optional because endpoints send different
/// subsets: classic page mode sends `total`/`current_page`/`last_page`/
/// `per_page`; the chat threads' cursor mode sends `has_more` and no
/// `per_page`, which is how the app tells the two modes apart.
class Pagination {
  /// Total number of items across all pages.
  int? total;

  /// Index of the page currently returned.
  int? currentPage;

  /// Index of the last available page.
  int? lastPage;

  /// Items per page. `null` in cursor mode.
  int? perPage;

  /// Whether more (older) items remain. `null` when the endpoint does not
  /// send it (every list except the chat threads).
  bool? hasMore;

  /// Creates a [Pagination] descriptor; all fields are optional.
  Pagination({
    this.total,
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.hasMore,
  });

  /// Returns a copy of this descriptor with the given fields overridden.
  Pagination copyWith({
    int? total,
    int? currentPage,
    int? lastPage,
    int? perPage,
    bool? hasMore,
  }) => Pagination(
    total: total ?? this.total,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    perPage: perPage ?? this.perPage,
    hasMore: hasMore ?? this.hasMore,
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
    hasMore: json["has_more"],
  );

  /// Serializes this descriptor back to a JSON map. `has_more` is written
  /// only when known, so lists that never send it round-trip unchanged.
  Map<String, dynamic> toJson() => {
    "total": total,
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
    if (hasMore != null) "has_more": hasMore,
  };
}
