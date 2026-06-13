import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

import '../../../constants/app_constants.dart';
import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';

/// Signature for the authenticated POST used to record consent on the server.
///
/// Defaults to [postHttp]; injectable so tests can supply a canned response
/// without opening a real connection.
typedef ConsentPoster = Future<Response> Function(String path);

/// Owns the user's silent-recording consent state (DG1).
///
/// Consent is recorded **server-side** — the source of truth, surviving
/// reinstall / new device — and **mirrored locally** in [GetStorage] for fast
/// synchronous checks at the capture point (where the patent flow decides
/// whether to record). Resolved as a `get_it` singleton (see `helpers/di.dart`).
///
/// - [hasConsented] reads the local mirror.
/// - [grantConsent] records consent on the server, then updates the mirror.
/// - [revokeConsent] clears the local mirror (in-app withdrawal); the live
///   OS camera-permission check is the other half of the capture-point gate.
/// - [syncFromServer] reconciles the mirror with the value the API returns on
///   login — the server always wins.
class ConsentService {
  /// Creates the service.
  ///
  /// [storage] is the local mirror (defaults to the app's [GetStorage]
  /// container) and [poster] is the authed POST (defaults to [postHttp]) —
  /// both injectable for unit tests.
  ConsentService({GetStorage? storage, ConsentPoster? poster})
    : _storage = storage ?? GetStorage(),
      _post = poster ?? postHttp;

  final GetStorage _storage;
  final ConsentPoster _post;

  /// Whether the user has consented to silent reaction-recording.
  ///
  /// Reads the local mirror; a non-null stored timestamp means consented.
  bool get hasConsented => _storage.read(kKeyRecordingConsentAt) != null;

  /// Records the user's consent on the server and mirrors it locally.
  ///
  /// Returns `true` when the server confirmed and the mirror was written;
  /// `false` on a non-success response or any transport error (the mirror is
  /// left untouched so a failed grant does not falsely read as consented).
  Future<bool> grantConsent() async {
    try {
      final response = await _post(EndPoints.recordingConsent());
      final body = response.data;
      final ok =
          response.statusCode == 200 && body is Map && body['success'] == true;
      if (ok) {
        final data = body['data'];
        final serverTimestamp =
            data is Map ? data['recording_consent_at'] : null;
        _storage.write(
          kKeyRecordingConsentAt,
          serverTimestamp ?? DateTime.now().toUtc().toIso8601String(),
        );
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Clears the local consent mirror (e.g. an explicit in-app withdrawal).
  void revokeConsent() => _storage.remove(kKeyRecordingConsentAt);

  /// Reconciles the local mirror with the server's [recordingConsentAt] value
  /// (from the login payload). The server is the source of truth: a non-null
  /// value sets the mirror, a null value clears it.
  void syncFromServer(String? recordingConsentAt) {
    if (recordingConsentAt != null) {
      _storage.write(kKeyRecordingConsentAt, recordingConsentAt);
    } else {
      _storage.remove(kKeyRecordingConsentAt);
    }
  }
}
