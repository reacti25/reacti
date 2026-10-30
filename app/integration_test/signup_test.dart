// Signing up on a device, against the throwaway test server: the Sign up
// link, the form with a birth date over the age limit, the terms, and the
// emailed code. The test server writes mail to its log; the host reads the
// code for the test. Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/otp.dart';
import 'support/wait.dart';

/// The new account's password.
const newPassword = 'LabPassw0rd!';

/// Types [text] into the form field whose hint is [hint].
Future<void> fill(WidgetTester tester, String hint, String text) async {
  final field = find.widgetWithText(TextFormField, hint);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}

/// Fills and sends the signup form for [email].
Future<void> fillSignupForm(WidgetTester tester, String email) async {
  await fill(tester, 'First Name', 'Lab');
  await fill(tester, 'Last Name', 'Newcomer');
  await fill(tester, 'Email Address', email);
  await fill(tester, 'Phone Number', '5550100');
  await fill(tester, 'New password', newPassword);
  await fill(tester, 'Confirm new password', newPassword);
  FocusManager.instance.primaryFocus?.unfocus();
  // The iPhone's keyboard slides away and the form moves: let it finish.
  await tester.pump(const Duration(seconds: 1));

  // The picker opens 25 years back, over the age limit: accept it.
  final dob = find.widgetWithText(TextFormField, 'Date of Birth');
  await tester.ensureVisible(dob);
  await tester.tap(dob);
  await pumpUntilFound(tester, find.text('OK'));
  await tester.tap(find.text('OK'));
  await tester.pump(const Duration(seconds: 1));

  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  final signUp = find.widgetWithText(CustomButton, 'Sign Up');
  await tester.ensureVisible(signUp);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(signUp);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up with the emailed code', (tester) async {
    final email = 'lab-${DateTime.now().millisecondsSinceEpoch}@reacti.test';

    await skipFirstRunScreens();
    app.main();
    await pumpUntilFound(tester, find.text('Sign In'));
    // "Sign up" ends the "Don't have an account? Sign up" line.
    final link = find.textContaining('have an account', findRichText: true);
    await pumpUntilFound(tester, link);
    final box = tester.getRect(link);
    await tester.tapAt(Offset(box.right - 8, box.center.dy));
    await pumpUntilFound(tester, find.text('First Name'));

    await fillSignupForm(tester, email);
    await pumpUntilFound(tester, find.text('Verify OTP'));
    final code = await emailedCode(tester, email);
    await tester.enterText(find.byType(EditableText).last, code);
    await tester.tap(find.widgetWithText(CustomButton, 'Continue'));

    // The account exists and its password works.
    await waitFor(
      () async {
        try {
          await E2eUser.login(endpoints.url, email, password: newPassword);
          return true;
        } on DioException {
          return false;
        }
      },
      what: 'the new account to log in',
      tester: tester,
    );
    await letPopupsFinish(tester);
  });
}
