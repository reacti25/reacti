// Profile and settings on a device, against the throwaway test server: edit
// the bio, change the password, log out and back in. Checked on the server.
// The password goes back to the seeded one at the end, for the journeys after.
// Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// The password the journey changes to, and back from.
const changedPassword = 'lab-changed-password';

/// Scrolls [label] into view and taps it.
Future<void> tapVisible(WidgetTester tester, String label) async {
  await pumpUntilFound(tester, find.text(label));
  await tester.ensureVisible(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text(label).last);
}

/// Profile tab, Edit Profile: writes a bio and saves it.
Future<void> editBio(WidgetTester tester, E2eUser alpha) async {
  await tapVisible(tester, 'Profile');
  await tapVisible(tester, 'Edit Profile');
  await pumpUntilFound(tester, find.text('Update Profile'));
  // Fields top to bottom: username, first, last, phone, email, bio.
  await tester.enterText(find.byType(TextFormField).at(5), 'bio from the lab');
  FocusManager.instance.primaryFocus?.unfocus();
  await tapVisible(tester, 'Update Profile');
  await waitFor(
    () async => (await alpha.profile())['bio'] == 'bio from the lab',
    what: 'the new bio on the server',
    tester: tester,
  );
}

/// Settings, Change Password: old, new and confirm, then saves. Both saves
/// return to the screen they came from (Profile, then Settings).
Future<void> changePassword(WidgetTester tester) async {
  await tapVisible(tester, 'Settings');
  await tapVisible(tester, 'Change Password');
  await pumpUntilFound(tester, find.byType(TextFormField));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), e2ePassword);
  await tester.enterText(fields.at(1), changedPassword);
  await tester.enterText(fields.at(2), changedPassword);
  FocusManager.instance.primaryFocus?.unfocus();
  await tapVisible(tester, 'Change Password');
  await waitFor(
    () async {
      try {
        await E2eUser.login(
          endpoints.url,
          userAEmail,
          password: changedPassword,
        );
        return true;
      } on Exception {
        return false;
      }
    },
    what: 'the new password to work on the server',
    tester: tester,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit profile, change password, log out and back in', (
    tester,
  ) async {
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    addTearDown(() async {
      final changed = await E2eUser.login(
        endpoints.url,
        userAEmail,
        password: changedPassword,
      ).then<E2eUser?>((u) => u, onError: (_) => null);
      await changed?.changePassword(changedPassword, e2ePassword);
    });

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await editBio(tester, alpha);
    await changePassword(tester);

    await pumpUntilFound(tester, find.text('Log Out'));
    await tapVisible(tester, 'Log Out');
    await pumpUntilFound(tester, find.text('Sign In'));
    final changed = await E2eUser.login(
      endpoints.url,
      userAEmail,
      password: changedPassword,
    );
    await changed.changePassword(changedPassword, e2ePassword);
    await logIn(tester, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await letPopupsFinish(tester);
  });
}
