// Sending while the server is unreachable fails with a message and loses
// nothing on the server, and once it is back sending works again. Driven by
// the testing lab (.github/workflows/testing-lab.yml).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/chat.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/wait.dart';

/// Whether the test server answers this device right now.
Future<bool> serverAnswers() async {
  try {
    await Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 2)),
    ).get('${endpoints.url}/check');
    return true;
  } on DioException catch (e) {
    // Any HTTP reply means it is up; only no reply means it is down.
    return e.response != null;
  }
}

/// Sends a message with the server unreachable, then again once it is back.
Future<void> sendWhileOffline(
  WidgetTester tester,
  E2eUser alpha,
  E2eUser bravo,
) async {
  await bravo.sendText(alpha.id, 'are you there?');
  await pumpUntilFound(tester, find.text('Smoke Bravo'));
  await tester.tap(find.text('Smoke Bravo'));
  await pumpUntilFound(tester, chatComposer);

  Future<bool> bravoHas(String text) async =>
      (await bravo.conversation(alpha.id)).any((m) => m['text'] == text);

  // To the app, a server it cannot reach looks exactly like no internet.
  // Photos then fail to load, which is expected offline: ignore only those.
  final reportError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.library != 'image resource service') reportError?.call(details);
  };
  askHost('offline');
  // Back online even if a step fails, or every journey after it fails too.
  addTearDown(() => askHost('online'));
  // The host acts when it reads the request, a moment later: wait for it.
  await waitFor(
    () async => !await serverAnswers(),
    what: 'the server to be unreachable',
    tester: tester,
  );
  await sendInChat(tester, 'sent offline');
  await pumpUntilFound(tester, find.text('An error occurred'));
  askHost('online');
  await waitFor(serverAnswers, what: 'the server to be back', tester: tester);
  await letPopupsFinish(tester);
  FlutterError.onError = reportError;
  expect(await bravoHas('sent offline'), isFalse);

  // The failed send reloads the chat, which fails offline too: the chat
  // shows "Couldn't load this conversation." and a Retry, as a user sees it.
  await pumpUntilFound(tester, find.text('Retry'));
  await tester.tap(find.text('Retry'));
  await pumpUntilFound(tester, chatComposer);

  await sendInChat(tester, 'sent back online');
  await waitFor(
    () => bravoHas('sent back online'),
    what: 'the message sent after reconnecting to reach smoke-b',
    tester: tester,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sending while offline fails cleanly and works once back', (
    tester,
  ) async {
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    await startLoggedIn(tester, app.main, userAEmail);
    await sendWhileOffline(tester, alpha, bravo);
    await letPopupsFinish(tester);
  });
}
