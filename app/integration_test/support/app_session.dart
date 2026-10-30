// Starts the real app for a device test and logs it in, past the first-run
// screens. Call once per test file: main() registers singletons.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reacti_app/constants/app_constants.dart';

import 'e2e_api.dart';
import 'wait.dart';

/// Marks the first-run screens and coach marks as seen, so the test goes from
/// login straight to the chats. Each has its own unit tests; here they would
/// only catch the taps.
Future<void> skipFirstRunScreens() async {
  await GetStorage.init();
  final storage = GetStorage();
  for (final key in [
    kKeyDemoSeen,
    kKeyTourSeen,
    kKeyTourFirstChatSeen,
    kKeyTourAttachSeen,
    kKeyTourSealedSeen,
    kKeyTourSentMediaSeen,
    kKeyCamMicPrimerShown,
  ]) {
    await storage.write(key, true);
  }
  await storage.write(kKeyIsFirstTime, false);
}

/// Logs into the app's login screen as [email].
Future<void> logIn(WidgetTester tester, String email) async {
  await pumpUntilFound(tester, find.text('Sign In'));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), e2ePassword);
  // The iPhone's on-screen keyboard covers the button: put it away first.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('Sign In'));
}

/// Starts the app with [appMain] and logs in as [email].
Future<void> startLoggedIn(
  WidgetTester tester,
  void Function() appMain,
  String email,
) async {
  await skipFirstRunScreens();
  appMain();
  await logIn(tester, email);
}
