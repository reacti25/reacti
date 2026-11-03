// The emailed 4-digit code (signup, password reset) for device tests. The test
// server writes mail to its log; on `askHost('otp EMAIL')` the lab's runner
// copies the code to the server's public folder, where the device fetches it.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'host.dart';
import 'wait.dart';

/// The code the host published for [email] ("EMAIL CODE"), or null while it
/// is not there yet. The email guards against an earlier journey's code.
Future<String?> _publishedCode(String email) async {
  try {
    final reply = await Dio().get<String>(
      Uri.parse(endpoints.url).resolve('/lab-otp.txt').toString(),
    );
    final match = RegExp(
      '^${RegExp.escape(email)} '
      r'(\d{4})$',
    ).firstMatch(reply.data?.trim() ?? '');
    return match?.group(1);
  } on DioException {
    return null;
  }
}

/// Asks the host for the code just mailed to [email] and waits for it.
Future<String> emailedCode(WidgetTester tester, String email) async {
  askHost('otp $email');
  String? code;
  await waitFor(
    () async => (code = await _publishedCode(email)) != null,
    what: 'the code mailed to $email',
    tester: tester,
  );
  return code!;
}
