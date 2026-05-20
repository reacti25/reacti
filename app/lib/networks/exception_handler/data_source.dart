// ignore_for_file: constant_identifier_names
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'error_response.dart';

/// Enumerates the outcome categories of a network operation.
///
/// Each value represents a server status class or a client-side transport
/// condition, and maps to a [Failure] via [DataSourceExtension.getFailure].
enum DataSource {
  /// 2xx success carrying data.
  SUCCESS,

  /// Success with no content body.
  NO_CONTENT,

  /// Server rejected the request (HTTP 400).
  BAD_REQUEST,

  /// Request forbidden (HTTP 403).
  FORBIDDEN,

  /// User not authorised (HTTP 401).
  UNAUTORISED,

  /// Requested resource not found (HTTP 404).
  NOT_FOUND,

  /// Server-side crash (HTTP 500).
  INTERNAL_SERVER_ERROR,

  /// Connection could not be established within the timeout.
  CONNECT_TIMEOUT,

  /// Request was cancelled before completing.
  CANCEL,

  /// Response was not received within the timeout.
  RECIEVE_TIMEOUT,

  /// Request body could not be sent within the timeout.
  SEND_TIMEOUT,

  /// Local cache read/write failure.
  CACHE_ERROR,

  /// No internet connection available.
  NO_INTERNET_CONNECTION,

  /// Fallback for any uncategorised error.
  DEFAULT,
}

/// Adds [getFailure] to [DataSource], translating an outcome into a [Failure].
extension DataSourceExtension on DataSource {
  /// Returns the [Failure] (code plus localised message) for this outcome.
  ///
  /// Messages are pulled from [ResponseMessage] and run through GetX's `.tr`
  /// for translation; codes come from [ResponseCode].
  Failure getFailure() {
    switch (this) {
      case DataSource.SUCCESS:
        return Failure(ResponseCode.SUCCESS, ResponseMessage.SUCCESS.tr);
      case DataSource.NO_CONTENT:
        return Failure(ResponseCode.NO_CONTENT, ResponseMessage.NO_CONTENT.tr);
      case DataSource.BAD_REQUEST:
        return Failure(
          ResponseCode.BAD_REQUEST,
          ResponseMessage.BAD_REQUEST.tr,
        );
      case DataSource.FORBIDDEN:
        return Failure(ResponseCode.FORBIDDEN, ResponseMessage.FORBIDDEN.tr);
      case DataSource.UNAUTORISED:
        return Failure(
          ResponseCode.UNAUTORISED,
          ResponseMessage.UNAUTORISED.tr,
        );
      case DataSource.NOT_FOUND:
        return Failure(ResponseCode.NOT_FOUND, ResponseMessage.NOT_FOUND.tr);
      case DataSource.INTERNAL_SERVER_ERROR:
        return Failure(
          ResponseCode.INTERNAL_SERVER_ERROR,
          ResponseMessage.INTERNAL_SERVER_ERROR.tr,
        );
      case DataSource.CONNECT_TIMEOUT:
        return Failure(
          ResponseCode.CONNECT_TIMEOUT,
          ResponseMessage.CONNECT_TIMEOUT.tr,
        );
      case DataSource.CANCEL:
        return Failure(ResponseCode.CANCEL, ResponseMessage.CANCEL.tr);
      case DataSource.RECIEVE_TIMEOUT:
        return Failure(
          ResponseCode.RECIEVE_TIMEOUT,
          ResponseMessage.RECIEVE_TIMEOUT.tr,
        );
      case DataSource.SEND_TIMEOUT:
        return Failure(
          ResponseCode.SEND_TIMEOUT,
          ResponseMessage.SEND_TIMEOUT.tr,
        );
      case DataSource.CACHE_ERROR:
        return Failure(
          ResponseCode.CACHE_ERROR,
          ResponseMessage.CACHE_ERROR.tr,
        );
      case DataSource.NO_INTERNET_CONNECTION:
        return Failure(
          ResponseCode.NO_INTERNET_CONNECTION,
          ResponseMessage.NO_INTERNET_CONNECTION.tr,
        );
      case DataSource.DEFAULT:
        return Failure(ResponseCode.DEFAULT, ResponseMessage.DEFAULT.tr);
    }
  }
}

/// Immutable value object describing a failed (or non-success) API outcome.
///
/// Pairs a numeric status code with a human-readable message for the UI.
final class Failure {
  /// The status code of the outcome (note: field name retains a typo).
  final int resonseCode;

  /// The localised, user-facing message describing the outcome.
  final String responseMessage;

  /// Creates a [Failure] from a [resonseCode] and [responseMessage].
  Failure(this.resonseCode, this.responseMessage);
  // {
  //   log("Getting called:$responseMessage");
  //   // ScaffoldMessenger.of(NavigationService.context).showSnackBar(SnackBar(
  //   //   content: Text(responseMessage),
  //   // ));
  // }
}

/// Converts an arbitrary thrown [error] into a structured [Failure].
///
/// Implements [Exception] so it can itself be thrown if needed. The resolved
/// outcome is exposed via [failure].
final class ErrorHandler implements Exception {
  /// The resolved failure for the handled error.
  late Failure failure;

  /// Builds an [ErrorHandler], classifying [error] into [failure].
  ///
  /// A [DioException] is routed through [_handleError]; anything else is
  /// logged and mapped to [DataSource.DEFAULT].
  ErrorHandler.handle(dynamic error) {
    if (error is DioException) {
      // dio error so its an error from response of the API or from dio itself
      failure = _handleError(error);
    } else {
      log(error.toString());
      // default error
      failure = DataSource.DEFAULT.getFailure();
    }
  }

  /// Maps a Dio [error] to a [Failure] based on its [DioExceptionType].
  ///
  /// For a `badResponse` with a usable status code/message the server's own
  /// values are preserved; otherwise it falls back to [DataSource.DEFAULT].
  Failure _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return DataSource.CONNECT_TIMEOUT.getFailure();
      case DioExceptionType.sendTimeout:
        return DataSource.SEND_TIMEOUT.getFailure();
      case DioExceptionType.receiveTimeout:
        return DataSource.RECIEVE_TIMEOUT.getFailure();
      case DioExceptionType.badResponse:
        if (error.response != null &&
            error.response?.statusCode != null &&
            error.response?.statusMessage != null) {
          return Failure(
            error.response?.statusCode ?? 0,
            error.response?.statusMessage ?? "",
          );
        } else {
          return DataSource.DEFAULT.getFailure();
        }
      case DioExceptionType.cancel:
        return DataSource.CANCEL.getFailure();
      default:
        return DataSource.DEFAULT.getFailure();
    }
  }
}
