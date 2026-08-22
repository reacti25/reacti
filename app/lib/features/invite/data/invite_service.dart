import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';
import '../model/inviter.dart';

/// Client seam for personal invites (Feature 5).
///
/// Kept provider-agnostic — callers only ever deal in the opaque code and the
/// `reacti.app/i/{code}` link — so a paid deferred-deep-link provider (Branch /
/// Adjust / …) can be added later as configuration, not surgery (DECISION D4).
///
/// The mutable [instance] is the seam tests swap with a fake.
class InviteService {
  /// The shared instance (swappable in tests).
  static InviteService instance = InviteService();

  /// The shareable link for [code], on the same host as the API (so a staging
  /// build links to staging.reacti.io and prod to reacti.io) — never the dead
  /// reacti.app. The backend serves a landing page at `/i/{code}`.
  String linkFor(String code) {
    final host = url.replaceFirst(RegExp(r'/api/?$'), '');
    return '$host/i/$code';
  }

  /// Mint (or fetch) the caller's reusable invite code; null on failure.
  Future<String?> mintCode() async {
    try {
      final res = await postHttp(EndPoints.mintInvite());
      if (res.statusCode == 200) {
        return (res.data['data']?['code']) as String?;
      }
    } catch (_) {
      // Swallow — the caller shows a soft failure, never blocks the user.
    }
    return null;
  }

  /// Resolve [code] to the inviter's public profile; null when unknown.
  Future<Inviter?> resolveInviter(String code) async {
    try {
      final res = await getHttp(EndPoints.resolveInvite(code));
      final data = res.data['data'];
      if (res.statusCode == 200 && data is Map) {
        return Inviter.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  /// Connect (befriend the inviter) via [code]; returns the inviter id or null.
  Future<int?> connect(String code) async {
    try {
      final res = await postHttp(EndPoints.connectInvite(code));
      if (res.statusCode == 200) {
        return (res.data['data']?['inviter_id']) as int?;
      }
    } catch (_) {}
    return null;
  }

  /// Extracts an invite code from pasted [input]: a `reacti.app/i/{code}` link
  /// (or any URL containing `/i/{code}`) or a bare alphanumeric code. Null when
  /// nothing usable is found.
  String? codeFromInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final inLink = RegExp(r'/i/([A-Za-z0-9]+)').firstMatch(trimmed);
    if (inLink != null) return inLink.group(1);

    if (RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)) return trimmed;
    return null;
  }
}
