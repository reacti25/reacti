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

/// A real 1x1 PNG: the server checks the file's content type, not its name.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// A logged-in test account on the test server.
class E2eUser {
  E2eUser._(this.id, this._dio);

  /// The account's user id.
  final int id;

  final Dio _dio;

  /// Logs [email] in on the test server at [baseUrl] (the app's BASE_URL).
  ///
  /// Throws a [DioException] if the server is down or refuses the login.
  static Future<E2eUser> login(String baseUrl, String email) async {
    final dio = Dio(
      BaseOptions(baseUrl: baseUrl, headers: {'Accept': 'application/json'}),
    );
    final reply = await dio.post(
      '/login',
      data: {'email': email, 'password': e2ePassword},
    );
    final data = reply.data['data'] as Map<String, dynamic>;
    dio.options.headers['Authorization'] = 'Bearer ${data['token']}';
    return E2eUser._(data['id'] as int, dio);
  }

  /// Sends a photo to [receiverId]; the server seals it. Returns its message id.
  Future<int> sendSealedPhoto(int receiverId) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(_tinyPng, filename: 'sealed.png'),
    });
    final reply = await _dio.post('/auth/chat/send/$receiverId', data: form);
    return reply.data['data']['chat']['id'] as int;
  }

  /// The messages between this account and [otherId], oldest first.
  Future<List<Map<String, dynamic>>> conversation(int otherId) async {
    final reply = await _dio.get('/auth/chat/conversation/$otherId');
    return (reply.data['data']['chat'] as List).cast<Map<String, dynamic>>();
  }
}

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
