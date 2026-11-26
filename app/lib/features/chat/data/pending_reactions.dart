import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';

import '../../../analytics/chat_send_analytics.dart';
import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import 'rx_send_group_message/api.dart';
import 'rx_send_message/api.dart';

/// Uploads one kept reaction; the default posts it with the send APIs.
typedef PendingReactionUpload = Future<void> Function(Map entry);

/// Reaction clips the server has not confirmed yet.
///
/// A reaction is remembered when its upload starts ([begin]) and forgotten
/// once the server has it ([end]). One cut off on the way (the viewer left
/// the app, switched account, or lost the network) stays and is sent again by
/// [resend], so it is not lost. Kept in [appData], which a logout does not
/// wipe; an entry is sent only by the account that recorded it.
///
/// Storage failures are swallowed: keeping a copy must never stop the
/// reaction upload itself (the patent flow).
///
/// ponytail: the clip stays in the camera's temp folder, which the phone may
/// purge while the app is closed; a purged clip is dropped. Copy it to app
/// storage if that shows up in the numbers.
/// ponytail: a reaction the server saved but whose answer was lost is sent
/// twice; add a server dedupe on (sender, reply_to) if that shows up.
class PendingReactions {
  /// Creates the store; [upload] defaults to the real send APIs.
  PendingReactions({PendingReactionUpload? upload}) : _upload = upload ?? _post;

  static const String _key = 'kKeyPendingReactions';

  final PendingReactionUpload _upload;

  /// Clips being uploaded right now by this run of the app, so [resend]
  /// never doubles an upload that is still going.
  final Set<String> _inFlight = {};

  /// Remembers the clip at [path] before its upload starts.
  ///
  /// [to] is the peer's user id, or the group id when [group] is true;
  /// [replyTo] is the media message the reaction answers.
  void begin({
    required String path,
    required int to,
    required bool group,
    required int replyTo,
  }) {
    _inFlight.add(path);
    try {
      _write([
        ..._entries().where((e) => e['path'] != path),
        {
          'path': path,
          'to': to,
          'group': group,
          'reply': replyTo,
          'owner': '${appData.read(kKeyUserId)}',
        },
      ]);
    } catch (_) {}
  }

  /// Ends the upload of [path]; forgets the clip when it was [sent].
  void end(String path, {required bool sent}) {
    _inFlight.remove(path);
    if (sent) _forget(path);
  }

  /// Sends again every kept clip of the signed-in account that is not
  /// uploading right now. A clip is forgotten once the server answers, even
  /// with an error (it will not change its mind), or when its file is gone; it
  /// stays only when the server was not reached.
  Future<void> resend() async {
    final entries = _entries();
    if (entries.isEmpty) return;
    final me = '${appData.read(kKeyUserId)}';
    for (final entry in entries) {
      final path = entry['path'] as String;
      if (entry['owner'] != me || _inFlight.contains(path)) continue;
      if (!File(path).existsSync()) {
        _forget(path);
        continue;
      }
      _inFlight.add(path);
      final watch = Stopwatch()..start();
      try {
        await _upload(entry);
        _forget(path);
        _track(entry, watch, success: true);
      } on DioException catch (e) {
        if (e.response != null) _forget(path);
        _track(entry, watch, success: false, error: e);
      } catch (_) {
        // Not a network error: the server answered, or the clip is unreadable.
        _forget(path);
      } finally {
        _inFlight.remove(path);
      }
    }
  }

  List<Map> _entries() {
    try {
      return List<Map>.from(appData.read<List>(_key) ?? const []);
    } catch (_) {
      return [];
    }
  }

  void _write(List<Map> entries) => appData.write(_key, entries);

  void _forget(String path) {
    try {
      _write(_entries().where((e) => e['path'] != path).toList());
    } catch (_) {}
  }

  /// Reports a resend as a `reaction_sent`, like the first try.
  void _track(
    Map entry,
    Stopwatch watch, {
    required bool success,
    Object? error,
  }) => trackMessageSend(
    scope: entry['group'] == true ? 'group' : 'private',
    type: 'reaction',
    ms: watch.elapsedMilliseconds,
    success: success,
    error: error,
  );

  static Future<void> _post(Map entry) {
    final file = XFile(entry['path'] as String);
    final to = entry['to'] as int;
    final reply = entry['reply'] as int;
    return entry['group'] == true
        ? SendGroupMessageApi.instance.sendGroupMessage(
          id: to,
          file: file,
          type: 'reaction',
          replyToId: reply,
        )
        : SendMessageApi.instance.sendMessage(
          id: to,
          file: file,
          type: 'reaction',
          replyToId: reply,
        );
  }
}

/// The app-wide store; replaceable in tests.
PendingReactions pendingReactions = PendingReactions();
