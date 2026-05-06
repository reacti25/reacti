import 'dart:convert';

class GetRequestResponse {
  bool? success;
  String? message;
  Data? data;
  int? code;

  GetRequestResponse({this.success, this.message, this.data, this.code});

  GetRequestResponse copyWith({
    bool? success,
    String? message,
    Data? data,
    int? code,
  }) => GetRequestResponse(
    success: success ?? this.success,
    message: message ?? this.message,
    data: data ?? this.data,
    code: code ?? this.code,
  );

  factory GetRequestResponse.fromRawJson(String str) =>
      GetRequestResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GetRequestResponse.fromJson(Map<String, dynamic> json) =>
      GetRequestResponse(
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
  List<Request>? requests;
  Pagination? pagination;

  Data({this.requests, this.pagination});

  Data copyWith({List<Request>? requests, Pagination? pagination}) => Data(
    requests: requests ?? this.requests,
    pagination: pagination ?? this.pagination,
  );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    requests:
        json["requests"] == null
            ? []
            : List<Request>.from(
              json["requests"]!.map((x) => Request.fromJson(x)),
            ),
    pagination:
        json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "requests":
        requests == null
            ? []
            : List<dynamic>.from(requests!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
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

class Request {
  int? id;
  Person? person;
  String? status;
  String? sentAt;
  dynamic acceptedAt;
  dynamic declinedAt;
  bool? isSent;

  Request({
    this.id,
    this.person,
    this.status,
    this.sentAt,
    this.acceptedAt,
    this.declinedAt,
    this.isSent,
  });

  Request copyWith({
    int? id,
    Person? person,
    String? status,
    String? sentAt,
    dynamic acceptedAt,
    dynamic declinedAt,
    bool? isSent,
  }) => Request(
    id: id ?? this.id,
    person: person ?? this.person,
    status: status ?? this.status,
    sentAt: sentAt ?? this.sentAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    declinedAt: declinedAt ?? this.declinedAt,
    isSent: isSent ?? this.isSent,
  );

  factory Request.fromRawJson(String str) => Request.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Request.fromJson(Map<String, dynamic> json) => Request(
    id: json["id"],
    person: json["person"] == null ? null : Person.fromJson(json["person"]),
    status: json["status"],
    sentAt: json["sent_at"],
    acceptedAt: json["accepted_at"],
    declinedAt: json["declined_at"],
    isSent: json["is_sent"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "person": person?.toJson(),
    "status": status,
    "sent_at": sentAt,
    "accepted_at": acceptedAt,
    "declined_at": declinedAt,
    "is_sent": isSent,
  };
}

class Person {
  int? id;
  String? firstName;
  String? lastName;
  String? username;
  String? avatar;
  String? fullName;

  Person({
    this.id,
    this.firstName,
    this.lastName,
    this.username,
    this.avatar,
    this.fullName,
  });

  Person copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? username,
    String? avatar,
    String? fullName,
  }) => Person(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    username: username ?? this.username,
    avatar: avatar ?? this.avatar,
    fullName: fullName ?? this.fullName,
  );

  factory Person.fromRawJson(String str) => Person.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json["id"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    username: json["username"],
    avatar: json["avatar"],
    fullName: json["full_name"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "last_name": lastName,
    "username": username,
    "avatar": avatar,
    "full_name": fullName,
  };
}
