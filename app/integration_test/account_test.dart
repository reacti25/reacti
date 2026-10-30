// The account's edges on a device, against the throwaway test server: the
// signup form refuses someone under 16, smoke-g resets a forgotten password
// with the emailed code and logs in with it, then deletes the account.
// Driven by the testing lab (.github/workflows/testing-lab.yml).

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

/// smoke-g's password after the reset.
const resetPassword = 'LabReset0rd!';

/// Taps [label] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(target);
}

/// Login screen → signup: a birth date 10 years back is refused.
Future<void> underAgeIsRefused(WidgetTester tester) async {
  final link = find.textContaining('have an account', findRichText: true);
  await pumpUntilFound(tester, link);
  final box = tester.getRect(link);
  await tester.tapAt(Offset(box.right - 8, box.center.dy));
  final dob = find.widgetWithText(TextFormField, 'Date of Birth');
  await pumpUntilFound(tester, dob);
  await tapVisible(tester, dob);

  // The calendar's pencil switches to typing the date, in the phone's format.
  await pumpUntilFound(tester, find.byIcon(Icons.edit_outlined));
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pump(const Duration(seconds: 1));
  final input = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  final now = DateTime.now();
  final young = DateTime(now.year - 10, now.month, 1);
  await tester.enterText(
    input,
    MaterialLocalizations.of(tester.element(input)).formatCompactDate(young),
  );
  await tester.tap(find.text('OK'));
  await tester.pump(const Duration(seconds: 1));

  await tapVisible(tester, find.widgetWithText(CustomButton, 'Sign Up'));
  await pumpUntilFound(
    tester,
    find.text('You must be at least 16 to use Reacti'),
  );
  await tester.binding.handlePopRoute();
}

/// Login screen → Forgot Password → code → new password.
Future<void> resetForgottenPassword(WidgetTester tester) async {
  await pumpUntilFound(tester, find.text('Forgot Password'));
  await tester.tap(find.text('Forgot Password'));
  final mail = find.widgetWithText(TextFormField, 'Enter your Mail');
  await pumpUntilFound(tester, mail);
  await tester.enterText(mail, userGEmail);
  await tapVisible(tester, find.widgetWithText(CustomButton, 'Send Code'));

  await pumpUntilFound(tester, find.text('Verify OTP'));
  final code = await emailedCode(tester, userGEmail);
  await tester.enterText(find.byType(EditableText).last, code);
  await tapVisible(tester, find.widgetWithText(CustomButton, 'Continue'));

  final fresh = find.widgetWithText(TextFormField, 'New password');
  await pumpUntilFound(tester, fresh);
  await tester.enterText(fresh, resetPassword);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirm new password'),
    resetPassword,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tapVisible(tester, find.widgetWithText(CustomButton, 'Save Changes'));
}

/// Profile → Settings → Delete Account → Delete.
Future<void> deleteAccount(WidgetTester tester) async {
  await pumpUntilFound(tester, find.text('Profile'));
  await letPopupsFinish(tester);
  await tester.tap(find.text('Profile').last);
  await pumpUntilFound(tester, find.text('Settings'));
  await tapVisible(tester, find.text('Settings'));
  await pumpUntilFound(tester, find.text('Delete Account'));
  await tapVisible(tester, find.text('Delete Account'));
  final confirm = find.widgetWithText(CustomButton, 'Delete');
  await pumpUntilFound(tester, confirm);
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(confirm);
}

/// Whether [email] can log in on the server with [password].
Future<bool> canLogIn(String email, String password) async {
  try {
    await E2eUser.login(endpoints.url, email, password: password);
    return true;
  } on DioException {
    return false;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('under 16 refused, forgotten password reset, account deleted', (
    tester,
  ) async {
    await skipFirstRunScreens();
    app.main();
    await underAgeIsRefused(tester);

    await resetForgottenPassword(tester);
    await waitFor(
      () => canLogIn(userGEmail, resetPassword),
      what: "smoke-g's new password to work",
      tester: tester,
    );

    await logIn(tester, userGEmail, password: resetPassword);
    await deleteAccount(tester);
    await pumpUntilFound(tester, find.text('Sign In'));
    await waitFor(
      () async => !await canLogIn(userGEmail, resetPassword),
      what: "smoke-g's account to be gone",
      tester: tester,
    );
    await letPopupsFinish(tester);
  });
}
