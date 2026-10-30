// Friends on a device, against the throwaway test server: accept a stranger's
// request from the Requests tab, and find someone by username and send them a
// request. Each checked on the other person's side of the server. Driven by
// the testing lab (.github/workflows/testing-lab.yml).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// Requests tab: accepts smoke-c's request (the row's tick icon).
Future<void> acceptRequest(WidgetTester tester, E2eUser charlie) async {
  await tester.tap(find.text('Requests').last);
  await pumpUntilFound(tester, find.text('Smoke Charlie'));
  final row = find.ancestor(
    of: find.text('Smoke Charlie'),
    matching: find.byType(ListTile),
  );
  // Tick first, cross second; neither has a label.
  await tester.tap(
    find.descendant(of: row, matching: find.byType(SvgPicture)).first,
  );
  await waitFor(
    () async => (await charlie.fetch('/friends/list')).contains('Alpha'),
    what: 'smoke-c to have alpha as a friend',
    tester: tester,
  );
}

/// Friends tab, Find people: searches smoke_d and sends a request.
Future<void> requestByUsername(WidgetTester tester, E2eUser delta) async {
  await tester.tap(find.text('Friends').last);
  await pumpUntilFound(tester, find.byTooltip('Find people on Reacti'));
  await tester.tap(find.byTooltip('Find people on Reacti'));
  await pumpUntilFound(tester, find.byIcon(Icons.search));
  await tester.tap(find.byIcon(Icons.search));
  await pumpUntilFound(tester, find.byType(TextFormField));
  await tester.enterText(find.byType(TextFormField).last, 'smoke_d');
  await pumpUntilFound(tester, find.text('Send Request'));
  await tester.tap(find.text('Send Request'));
  await waitFor(
    () async => (await delta.fetch('/friends/requests')).contains('Alpha'),
    what: "alpha's request to reach smoke-d",
    tester: tester,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accept a request, and find someone by username', (tester) async {
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    final charlie = await E2eUser.login(endpoints.url, userCEmail);
    final delta = await E2eUser.login(endpoints.url, userDEmail);
    await charlie.sendFriendRequest(alpha.id);

    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await acceptRequest(tester, charlie);
    await requestByUsername(tester, delta);
    await letPopupsFinish(tester);
  });
}
