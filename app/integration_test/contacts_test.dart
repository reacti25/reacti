// The Contacts tab on a device, against the throwaway test server: "Smoke
// Echo" (smoke-e's phone number) is put in the phone's contacts, the lab
// grants access; the app matches the number to the account, alpha sends a
// request from the row, then stops and restarts using contacts. Driven by the
// testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// The contact the test adds to the phone: smoke-e's number
/// (e2e_backend.sh gives smoke-e +15550005).
const contactName = 'Smoke Echo';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('find a friend among the phone contacts', (tester) async {
    final echo = await E2eUser.login(endpoints.url, userEEmail);
    // The app may only read contacts, so the contact comes from outside it:
    // adb on Android (android_e2e.sh). The iPhone grants full access, so
    // there the test writes it through the app's contacts plugin (the
    // simulator's own vCard import opened its Contacts app and sent Reacti
    // to the home screen).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FlutterContacts.create(
        const Contact(
          name: Name(first: 'Smoke', last: 'Echo'),
          phones: [Phone(number: '+15550005')],
        ),
      );
    }

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await letPopupsFinish(tester);
    await tester.tap(find.text('Friends').last);
    await pumpUntilFound(tester, find.text('Contacts'));
    await tester.tap(find.text('Contacts').last);

    // Access is granted already, so the list loads with no prompt and the
    // number is matched to smoke-e on the server. The iPhone simulator ships
    // sample contacts above ours: search, as a person with many would.
    final search = find.widgetWithText(TextField, 'Search contact..');
    await pumpUntilFound(tester, search);
    await tester.enterText(search, 'Smoke');
    await pumpUntilFound(tester, find.text(contactName));
    await pumpUntilFound(tester, find.text('Add friend'));
    await tester.tap(find.text('Add friend').first);
    await waitFor(
      () async => (await echo.fetch('/friends/requests')).contains('Alpha'),
      what: "alpha's request to reach smoke-e",
      tester: tester,
    );
    await pumpUntilFound(tester, find.text('Requested'));

    // Sharing is reversible both ways.
    await tester.tap(find.text('Stop using contacts'));
    await pumpUntilFound(tester, find.text('Find friends'));
    await tester.tap(find.text('Find friends'));
    await pumpUntilFound(tester, find.text('Stop using contacts'));
    await tester.enterText(search, 'Smoke');
    await pumpUntilFound(tester, find.text(contactName));
    await letPopupsFinish(tester);
  });
}
