import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../networks/auth_token_store.dart';

/// Fetches view-once media bytes from the authed private-media endpoint.
///
/// A swappable seam (like `reactionRecorder` / `screenshotGuard`) so the
/// viewer can be widget-tested with a fake instead of a real network call.
/// Deliberately **memory-only** — the bytes are never written to a disk cache,
/// so nothing survives after the viewer is dropped (view-once must leave no
/// trace on the device).
abstract class OneTimeMediaFetcher {
  /// GETs [url] with the caller's bearer token and returns the raw bytes.
  /// Throws on any transport/HTTP failure; the viewer shows an error state.
  Future<Uint8List> fetch(String url);
}

/// Real fetcher backed by a one-off Dio call carrying the auth header.
class RealOneTimeMediaFetcher implements OneTimeMediaFetcher {
  @override
  Future<Uint8List> fetch(String url) async {
    final token = AuthTokenStore.instance.token ?? '';
    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}

/// Swappable fetcher instance; tests replace it with a fake.
OneTimeMediaFetcher oneTimeMediaFetcher = RealOneTimeMediaFetcher();
