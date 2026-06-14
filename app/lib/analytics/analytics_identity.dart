import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Turns a raw user id into the pseudonymous `distinct_id` used in analytics.
///
/// Privacy rule (non-negotiable): the raw user id never leaves the device. We
/// send a one-way SHA-256 hash instead, so behaviour can be analysed and the
/// same user correlated across events without the analytics vendor ever holding
/// an identifying id. An optional per-environment [salt] makes the hash specific
/// to Reacti (so it cannot be cross-referenced against another system's hashes).
class AnalyticsIdentity {
  AnalyticsIdentity._();

  /// Returns the hex SHA-256 of `salt:rawUserId`.
  ///
  /// [rawUserId] is the application user id (e.g. the numeric id as a string).
  /// [salt] is an optional app/environment salt; when empty the hash is of the
  /// id alone (still pseudonymous, just not salted). Returns an empty string for
  /// an empty [rawUserId] (i.e. an anonymous, not-yet-identified user).
  static String hashUserId(String rawUserId, {String salt = ''}) {
    if (rawUserId.isEmpty) return '';
    final input = salt.isEmpty ? rawUserId : '$salt:$rawUserId';
    return sha256.convert(utf8.encode(input)).toString();
  }
}
