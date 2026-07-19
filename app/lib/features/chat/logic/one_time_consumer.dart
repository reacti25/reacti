import 'package:dio/dio.dart';

import '../../../networks/auth_token_store.dart';

/// Signals the server to destroy a view-once media file now — fired when the
/// receiver closes the viewer, so it does not linger until the fetch window
/// lapses.
///
/// A swappable seam (like `oneTimeMediaFetcher`) so the viewer can be tested
/// without a real network call. Fire-and-forget: the server enforces the
/// window and a janitor is the backstop, so a failed/dropped consume never
/// leaves the media viewable — it just delays physical deletion.
abstract class OneTimeConsumer {
  /// POSTs the consume endpoint at [consumeUrl] (the media's fetch URL plus
  /// `/consume`). Never throws — failures are swallowed.
  Future<void> consume(String consumeUrl);
}

/// Real consumer backed by a one-off authed Dio POST.
class RealOneTimeConsumer implements OneTimeConsumer {
  @override
  Future<void> consume(String consumeUrl) async {
    try {
      final token = AuthTokenStore.instance.token ?? '';
      await Dio().post(
        consumeUrl,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort: the server window + janitor guarantee destruction even if
      // this exit-signal never lands.
    }
  }
}

/// Swappable consumer instance; tests replace it with a fake.
OneTimeConsumer oneTimeConsumer = RealOneTimeConsumer();
