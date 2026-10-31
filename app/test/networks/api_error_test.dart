// apiErrorMessage: what a failed request shows, including when the phone is
// offline and there is no reply at all (that used to throw a null-check error).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/networks/api_error.dart';

/// A failed request, with [reply] as the server's answer (if any).
DioException failed({Object? reply, int status = 422}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    response:
        reply == null
            ? null
            : Response(
              requestOptions: request,
              statusCode: status,
              data: reply,
            ),
  );
}

void main() {
  test('shows the server message when there is one', () {
    expect(apiErrorMessage(failed(reply: {'message': 'Nope'})), 'Nope');
  });

  test('offline (no reply at all) shows the no-connection message', () {
    expect(apiErrorMessage(failed()), kNoConnectionMessage);
  });

  test('a reply without a message falls back to the no-connection message', () {
    expect(
      apiErrorMessage(failed(reply: '<html>502</html>', status: 502)),
      kNoConnectionMessage,
    );
    expect(apiErrorMessage(failed(reply: {'code': 500})), kNoConnectionMessage);
  });

  test('error handlers never assume a reply (offline has none)', () {
    final offenders =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where(
              (f) => f.readAsLinesSync().any(
                (l) =>
                    !l.trim().startsWith('//') &&
                    // A forced read, or the message handed on as-is: both
                    // break when there was no reply (login did the second).
                    (l.contains('response!') ||
                        RegExp(r"data\[.message.\]\)").hasMatch(l)),
              ),
            )
            .map((f) => f.path)
            .toList();
    expect(offenders, isEmpty);
  });
}
