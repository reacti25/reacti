// ignore_for_file: constant_identifier_names

/// User-facing message strings keyed by outcome, mirroring [ResponseCode].
///
/// Used by [DataSource.getFailure] to build a [Failure]'s message. Acts as a
/// namespace — every member is a static constant.
final class ResponseMessage {
  /// Private constructor — this class is never instantiated.
  ResponseMessage._();
  // API response messages

  /// Message for a successful response carrying data.
  static const String SUCCESS = "Success"; // Success with data

  /// Message for a successful response with no body.
  static const String NO_CONTENT =
      "Success with no content"; // Success with no data (no content)

  /// Message for an HTTP 400 rejection.
  static const String BAD_REQUEST =
      "Bad request. Try again later"; // Failure, API rejected request

  /// Message for an HTTP 401 unauthorised response.
  static const String UNAUTORISED =
      "User unauthorized. Try again later"; // Failure, user is not authorized

  /// Message for an HTTP 403 forbidden response.
  static const String FORBIDDEN =
      "Forbidden request. Try again later"; // Failure, API rejected request

  /// Message for an HTTP 500 server error.
  static const String INTERNAL_SERVER_ERROR =
      "Something went wrong. Try again later"; // Failure, crash on the server side

  /// Message for an HTTP 404 not-found response.
  static const String NOT_FOUND =
      "URL not found. Try again later"; // Failure, resource not found

  // Local status codes

  /// Message for a connection timeout.
  static const String CONNECT_TIMEOUT = "Timeout. Try again later";

  /// Message for a cancelled request.
  static const String CANCEL = "Request canceled";

  /// Message for a receive timeout.
  static const String RECIEVE_TIMEOUT = "Timeout. Try again later";

  /// Message for a send timeout.
  static const String SEND_TIMEOUT = "Timeout. Try again later";

  /// Message for a local cache error.
  static const String CACHE_ERROR = "Cache error. Try again later";

  /// Message shown when there is no internet connection.
  static const String NO_INTERNET_CONNECTION =
      "Please check your internet connection";

  /// Fallback message for uncategorised errors.
  static const String DEFAULT = "Something went wrong";

  // Add more descriptive comments or documentation as needed
}

/// Numeric status codes keyed by outcome, mirroring [ResponseMessage].
///
/// Standard HTTP codes are positive; client-side transport conditions use
/// negative sentinel values so they cannot collide with real HTTP codes.
final class ResponseCode {
  /// Private constructor — this class is never instantiated.
  ResponseCode._();

  /// HTTP 200 — success with data.
  static const int SUCCESS = 200; // success with data
  /// HTTP 201 — success with no content.
  static const int NO_CONTENT = 201; // success with no data (no content)

  /// HTTP 400 — request rejected by the API.
  static const int BAD_REQUEST = 400; // failure, API rejected request

  /// HTTP 401 — user not authorised.
  static const int UNAUTORISED = 401; // failure, user is not authorised

  /// HTTP 403 — request forbidden.
  static const int FORBIDDEN = 403; //  failure, API rejected request

  /// HTTP 500 — server-side crash.
  static const int INTERNAL_SERVER_ERROR = 500; // failure, crash in server side

  /// HTTP 404 — resource not found.
  static const int NOT_FOUND = 404; // failure, not found

  // local status code

  /// Sentinel code for a connection timeout.
  static const int CONNECT_TIMEOUT = -1;

  /// Sentinel code for a cancelled request.
  static const int CANCEL = -2;

  /// Sentinel code for a receive timeout.
  static const int RECIEVE_TIMEOUT = -3;

  /// Sentinel code for a send timeout.
  static const int SEND_TIMEOUT = -4;

  /// Sentinel code for a local cache error.
  static const int CACHE_ERROR = -5;

  /// Sentinel code for no internet connection.
  static const int NO_INTERNET_CONNECTION = -6;

  /// Sentinel code for an uncategorised error.
  static const int DEFAULT = -7;
}
