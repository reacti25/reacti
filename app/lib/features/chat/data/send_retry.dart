import 'package:dio/dio.dart';

/// Bounded retry for message/reaction uploads on flaky networks — branch 2.4 of
/// docs/PLAN-media-timing-and-speed-2026-06-23.md, scoped to coordinate with
/// docs/PLAN-reaction-reliability-2026-06-20.md (which owns the failure UX,
/// failure-reason events and any server-side idempotency).

/// Whether a failed send may be **safely** retried.
///
/// Retries ONLY transport errors that prove the request never reached the
/// server — a failed/lost connection or a connect timeout. Those can't have
/// been processed, so retrying can't create a **duplicate** message — critical
/// for the patented reaction upload, which must never be sent twice. Anything
/// that reached the server is NOT retried: a slow response (`receiveTimeout`),
/// an HTTP error (`badResponse`), or a mid-body `sendTimeout` may already have
/// persisted server-side. Retrying those safely needs server idempotency, which
/// is the reaction-reliability plan's job.
bool isRetriableSendError(Object error) {
  if (error is! DioException) return false;
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout;
}

/// Runs [send] with a bounded retry on [isRetriableSendError] failures — up to
/// [maxAttempts], awaiting [delay] between tries.
///
/// [send] MUST rebuild its request on each call: a Dio `FormData` is single-use,
/// so the same instance can't be re-posted. Non-retriable errors, and the last
/// attempt, rethrow unchanged.
Future<T> withSendRetry<T>(
  Future<T> Function() send, {
  int maxAttempts = 3,
  Future<void> Function(int attempt) delay = _backoff,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await send();
    } on DioException catch (e) {
      if (attempt >= maxAttempts || !isRetriableSendError(e)) rethrow;
      await delay(attempt);
    }
  }
}

/// Linear backoff (1s, 2s, …) between retries; sends are user-initiated and few.
Future<void> _backoff(int attempt) =>
    Future.delayed(Duration(seconds: attempt));
