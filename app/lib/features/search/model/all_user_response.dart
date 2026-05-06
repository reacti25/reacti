import 'dart:convert';

class AllUserResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  AllUserResponse({this.success, this.message, this.data, this.code});

  AllUserResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => AllUserResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  factory AllUserResponse.fromRawJson(String str) =>
      AllUserResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AllUserResponse.fromJson(Map<String, dynamic> json) =>
      AllUserResponse(
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
  List<Datum>? data;
  Pagination? pagination;

  Data({this.data, this.pagination});

  Data copyWith({List<Datum>? data, Pagination? pagination}) =>
      Data(data: data ?? this.data, pagination: pagination ?? this.pagination);

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    data:
        json["data"] == null
            ? []
            : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "data":
        data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class Datum {
  int? id;
  String? fullName;
  String? username;
  String? avatar;
  bool? isFriend;
  bool? isRequestSent;

  Datum({
    this.id,
    this.fullName,
    this.username,
    this.avatar,
    this.isFriend,
    this.isRequestSent,
  });

  Datum copyWith({
    int? id,
    String? fullName,
    String? username,
    String? avatar,
    bool? isFriend,
    bool? isRequestSent,
  }) => Datum(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    username: username ?? this.username,
    avatar: avatar ?? this.avatar,
    isFriend: isFriend ?? this.isFriend,
    isRequestSent: isRequestSent ?? this.isRequestSent,
  );

  factory Datum.fromRawJson(String str) => Datum.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    fullName: json["full_name"],
    username: json["username"],
    avatar: json["avatar"],
    isFriend: json["is_friend"],
    isRequestSent: json["is_request_sent"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "full_name": fullName,
    "username": username,
    "avatar": avatar,
    "is_friend": isFriend,
    "is_request_sent": isRequestSent,
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
