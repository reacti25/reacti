import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Turns a raw user id into the pseudonymous `distinct_id` used in analytics.
///
/// Privacy rule (non-negotiable): the raw user id never leaves the device. We
/// send a one-way hash instead, so behaviour can be analysed and the same user
/// correlated across events without the analytics vendor ever holding an
/// identifying id.
///
/// **The salt is required and must be a high-entropy secret.** Reacti user ids
/// are short and sequential, so a *plain* SHA-256 of the id is trivially
/// reversible by brute force (hash `1..N` and match). A secret per-environment
/// salt defeats that — without the salt the digest cannot be reversed. If no
/// salt is configured this returns an **empty** string (an anonymous,
/// un-attributed user) rather than ever producing a reversible unsalted hash —
/// the safe failure mode.
class AnalyticsIdentity {
  AnalyticsIdentity._();

  /// Returns the hex SHA-256 of `salt + ':' + rawUserId`, or an empty string
  /// when either input is empty.
  ///
  /// [rawUserId] is the application user id (e.g. the numeric id as a string).
  /// [salt] is the per-environment secret salt; an empty salt yields an empty
  /// result (no reversible unsalted hash is ever emitted). An empty
  /// [rawUserId] (anonymous user) also yields an empty result.
  static String hashUserId(String rawUserId, {required String salt}) {
    if (rawUserId.isEmpty || salt.isEmpty) return '';
    return sha256.convert(utf8.encode('$salt:$rawUserId')).toString();
  }
}
