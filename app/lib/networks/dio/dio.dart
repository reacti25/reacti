import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

import '../../helpers/feature_flags.dart';
import '../auth_token_store.dart';
import '../endpoints.dart';
import 'analytics_opt_out_interceptor.dart';
import 'log.dart';

/// Whether HTTP requests should route through the **native** platform stack
/// (NSURLSession via `cupertino_http` on iOS — HTTP/3 + connection migration —
/// and Cronet on Android) instead of Dart's default client.
///
/// Branch 3.3 of `docs/PLAN-media-timing-and-speed-2026-06-23.md`. Gated by the
/// off-by-default [Flags.nativeHttp]: with the flag absent (every prod build and
/// all tests) this returns false and the client is byte-for-byte the previous
/// Dart-stack client, so the patented multipart upload path is untouched until
/// the flag is deliberately flipped on (and remotely killable via PostHog).
@visibleForTesting
bool useNativeHttpAdapter() =>
    FeatureFlags.instance.isEnabled(Flags.nativeHttp);

/// Process-wide singleton owning the shared [Dio] HTTP client.
///
/// Centralises client configuration so the whole app issues requests through
/// one instance with consistent timeouts, headers, and logging. The client is
/// rebuilt by [create]/[update]/[updateLanguage] as the auth or language
/// context changes.
final class DioSingleton {
  /// The single eagerly-created instance backing [instance].
  static final DioSingleton _singleton = DioSingleton._internal();

  /// Shared cancellation token attached to every request, so all in-flight
  /// calls can be cancelled together.
  static CancelToken cancelToken = CancelToken();

  /// Live analytics opt-out predicate, read per request by the
  /// [AnalyticsOptOutInterceptor] to decide whether to stamp the
  /// `X-Analytics-Opt-Out` header. Defaults to opted-in; bootstrap points it at
  /// the persisted preference. Static so it survives client rebuilds.
  static bool Function() isAnalyticsOptedOut = () => false;

  /// Private constructor enforcing the singleton pattern.
  DioSingleton._internal();

  /// The shared [DioSingleton] instance.
  static DioSingleton get instance => _singleton;

  /// The active [Dio] client; assigned by [create] before first use.
  late Dio dio;

  /// Builds a [Dio] over [options] with the shared interceptors, and — only
  /// when [useNativeHttpAdapter] is true — swaps in the native HTTP stack.
  /// The flag is read here, at client-build time, so a remote flip takes effect
  /// on the next client rebuild (startup/login/language change).
  Dio _client(BaseOptions options) {
    final client =
        Dio(options)
          ..interceptors.add(AnalyticsOptOutInterceptor(isAnalyticsOptedOut))
          ..interceptors.add(Logger());
    if (useNativeHttpAdapter()) {
      client.httpClientAdapter = NativeAdapter();
    }
    return client;
  }

  /// How long to wait to *establish* a connection before failing. Short on
  /// purpose: a dead server or no network now surfaces in seconds instead of
  /// leaving the user on a ~10-minute spinner.
  static const Duration _connectTimeout = Duration(seconds: 30);

  /// How long to wait for response data. Kept generous as a conservative
  /// bound — a reaction-video upload on a slow network can take a while before
  /// its response arrives, and the request-send itself is unbounded — so this
  /// is deliberately not tightened here.
  static const Duration _receiveTimeout = Duration(minutes: 10);

  /// Builds the unauthenticated [dio] client.
  ///
  /// Called once at startup. Sets the base URL to [url], the
  /// [_connectTimeout]/[_receiveTimeout] timeouts, the `Accept` header, and
  /// attaches the [Logger] interceptor.
  void create() {
    BaseOptions options = BaseOptions(
      baseUrl: url,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE},
    );
    dio = _client(options);
  }

  /// Rebuilds [dio] as an authenticated client.
  ///
  /// Re-creates the client with a `Bearer` Authorization header carrying the
  /// [auth] token, so subsequent requests are authenticated. Called after
  /// login and when restoring a stored session.
  void update(String auth) {
    if (kDebugMode) {
      print("Dio update");
    }

    BaseOptions options = BaseOptions(
      baseUrl: url,
      responseType: ResponseType.json,
      headers: {
        NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE,
        NetworkConstants.AUTHORIZATION: "Bearer $auth",
      },
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    );
    dio = _client(options);
  }

  /// Rebuilds [dio] when the app language changes.
  ///
  /// Re-creates the authenticated client (token re-read from storage) for the
  /// given [countryCode]. The country code is logged in debug mode; the new
  /// client otherwise mirrors [update].
  void updateLanguage(String countryCode) {
    if (kDebugMode) {
      print("Dio update $countryCode");
    }
    BaseOptions options = BaseOptions(
      baseUrl: url,
      responseType: ResponseType.json,
      headers: {
        NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE,
        NetworkConstants.AUTHORIZATION:
            "Bearer ${AuthTokenStore.instance.token ?? ''} ",
      },
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    );
    dio = _client(options);
  }
}

/// Issues a POST request to [path] through the shared [DioSingleton] client.
///
/// Optional [data] is the request body and optional [onSendProgress] receives
/// upload progress callbacks (used by multipart uploads). The request is
/// bound to [DioSingleton.cancelToken]. Returns the Dio [Response].
Future<Response> postHttp(
  String path, [
  dynamic data,
  ProgressCallback? onSendProgress,
]) => DioSingleton.instance.dio.post(
  path,
  data: data,
  cancelToken: DioSingleton.cancelToken,
  onSendProgress: onSendProgress, // This will be used if provided
);

/// Issues a PUT request to [path] with optional body [data].
///
/// Bound to [DioSingleton.cancelToken]. Returns the Dio [Response].
Future<Response> putHttp(String path, [dynamic data]) => DioSingleton
    .instance
    .dio
    .put(path, data: data, cancelToken: DioSingleton.cancelToken);

/// Issues a GET request to [path].
///
/// The [data] parameter is accepted for signature symmetry but is not sent.
/// Bound to [DioSingleton.cancelToken]. Returns the Dio [Response].
Future<Response> getHttp(String path, [dynamic data]) =>
    DioSingleton.instance.dio.get(path, cancelToken: DioSingleton.cancelToken);

/// Issues a DELETE request to [path] with optional body [data].
///
/// Bound to [DioSingleton.cancelToken]. Returns the Dio [Response].
Future<Response> deleteHttp(String path, [dynamic data]) => DioSingleton
    .instance
    .dio
    .delete(path, data: data, cancelToken: DioSingleton.cancelToken);
