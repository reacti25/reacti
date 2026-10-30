// The scripted second user for device tests: talks to the throwaway test
// server (.github/scripts/e2e_backend.sh) straight over HTTP, so one device
// can test a two-person flow. Plan: docs/PLAN-device-testing-2026-10-29.md.

import 'dart:convert';

import 'package:dio/dio.dart';

/// Password of the seeded smoke accounts, passed in with
/// `--dart-define=E2E_PASSWORD=...` (the test server's STAGING_SEED_PASSWORD).
const e2ePassword = String.fromEnvironment('E2E_PASSWORD');

/// The smoke account the app logs in as (the receiver).
const userAEmail = 'smoke-a@reacti.test';

/// The smoke account the test plays from the server side (the sender).
const userBEmail = 'smoke-b@reacti.test';

/// The strangers e2e_backend.sh adds (nobody's friend yet).
const userCEmail = 'smoke-c@reacti.test';
const userDEmail = 'smoke-d@reacti.test';

/// A real 1x1 PNG: the server checks the file's content type, not its name.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// The group the seeder puts both smoke accounts in.
const smokeGroupName = 'Smoke Test Group';

/// A logged-in test account on the test server.
class E2eUser {
  E2eUser._(this.id, this._dio);

  /// The account's user id.
  final int id;

  final Dio _dio;

  /// Logs [email] in on the test server at [baseUrl] (the app's BASE_URL),
  /// with the seeded password unless [password] is given.
  ///
  /// Throws a [DioException] if the server is down or refuses the login.
  static Future<E2eUser> login(
    String baseUrl,
    String email, {
    String password = e2ePassword,
  }) async {
    final dio = Dio(
      BaseOptions(baseUrl: baseUrl, headers: {'Accept': 'application/json'}),
    );
    final reply = await dio.post(
      '/login',
      data: {'email': email, 'password': password},
    );
    final data = reply.data['data'] as Map<String, dynamic>;
    dio.options.headers['Authorization'] = 'Bearer ${data['token']}';
    return E2eUser._(data['id'] as int, dio);
  }

  /// Sends [receiverId] a friend request.
  Future<void> sendFriendRequest(int receiverId) =>
      _dio.post('/friends/send-request', data: {'receiver_id': receiverId});

  /// The raw JSON reply of GET [path], to look for a name or username in.
  Future<String> fetch(String path) async =>
      jsonEncode((await _dio.get(path)).data);

  /// This user's profile as the server holds it.
  Future<Map<String, dynamic>> profile() async =>
      (await _dio.get('/profile')).data['data'] as Map<String, dynamic>;

  /// Changes this user's password from [current] to [next].
  Future<void> changePassword(String current, String next) => _dio.post(
    '/update-password',
    data: {
      'current_password': current,
      'password': next,
      'password_confirmation': next,
    },
  );

  /// Sends a photo to [receiverId]; the server seals it. Returns its message id.
  Future<int> sendSealedPhoto(int receiverId) async {
    final reply = await _dio.post(
      '/auth/chat/send/$receiverId',
      data: _photo(),
    );
    return reply.data['data']['chat']['id'] as int;
  }

  /// Sends [text] to [receiverId].
  Future<void> sendText(int receiverId, String text) =>
      _dio.post('/auth/chat/send/$receiverId', data: {'text': text});

  /// The id of this account's group called [name].
  Future<int> groupId(String name) async {
    final reply = await _dio.get('/auth/group/list');
    final groups = (reply.data['groups'] as List).cast<Map<String, dynamic>>();
    return groups.firstWhere((g) => g['name'] == name)['id'] as int;
  }

  /// Sends a photo to group [groupId]; the server seals it. Returns its id.
  Future<int> sendSealedPhotoToGroup(int groupId) async {
    final reply = await _dio.post('/auth/group/$groupId/send', data: _photo());
    return reply.data['data']['message']['id'] as int;
  }

  /// The messages of group [groupId].
  Future<List<Map<String, dynamic>>> groupMessages(int groupId) async {
    final reply = await _dio.get('/auth/group/$groupId/messages');
    return (reply.data['data']['messages'] as List)
        .cast<Map<String, dynamic>>();
  }

  /// This account's invite code (one per account; the same on every call).
  Future<String> inviteCode() async {
    final reply = await _dio.post('/invites');
    return reply.data['data']['code'] as String;
  }

  /// The messages between this account and [otherId], oldest first.
  Future<List<Map<String, dynamic>>> conversation(int otherId) async {
    final reply = await _dio.get('/auth/chat/conversation/$otherId');
    return (reply.data['data']['chat'] as List).cast<Map<String, dynamic>>();
  }
}

/// A fresh upload form holding the test photo (a form can be sent only once).
FormData _photo() => FormData.fromMap({
  'file': MultipartFile.fromBytes(_tinyPng, filename: 'sealed.png'),
});

/// True when [messages] holds a reaction from [senderId] answering [messageId].
bool hasReactionTo(
  List<Map<String, dynamic>> messages, {
  required int messageId,
  required int senderId,
}) => messages.any(
  (m) =>
      m['message_type'] == 'reaction' &&
      m['sender_id'] == senderId &&
      (m['reply_to'] as Map?)?['id'] == messageId,
);
