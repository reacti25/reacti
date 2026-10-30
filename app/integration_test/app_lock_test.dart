// App Lock: leave the app, come back, and it is locked until the phone's own
// unlock passes (a PIN on Android, Face ID on the iPhone simulator, both
// worked by the host). Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/main.dart' as app;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/lifecycle.dart';
import 'support/wait.dart';

/// Leaves the app with App Lock on, comes back, and unlocks it.
Future<void> lockAndUnlock(WidgetTester tester) async {
  logLifecycle(); // a lock that never comes shows whether the app ever left
  askHost('lock-setup');
  final storage = GetStorage();
  await storage.write(kKeyAppLockEnabled, true);
  await storage.write(kKeyAppLockDelay, 'immediately');

  askHost('home');
  // No frames while backgrounded: wait in plain time, not with pump.
  await Future<void>.delayed(const Duration(seconds: 3));
  askHost('launch');
  await pumpUntilFound(tester, find.text('Reacti is locked'));

  // The phone's own unlock screen: Flutter cannot see it, the host passes it.
  // ponytail: up to 3 tries, as a person taps Unlock again; the simulator's
  // Face ID sheet sometimes misses a match sent while it is still opening.
  final locked = find.text('Reacti is locked');
  for (var attempt = 1; attempt <= 3; attempt++) {
    await tester.tap(find.text('Unlock'));
    askHost('unlock');
    try {
      await waitFor(
        () async => locked.evaluate().isEmpty,
        what: 'the phone to unlock the app',
        tester: tester,
        timeout: Duration(seconds: attempt < 3 ? 15 : 60),
      );
      return;
    } on TestFailure {
      if (attempt == 3) rethrow;
      debugPrint('unlock attempt $attempt did not open the app, retrying');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Lock locks on return and unlocks with the phone', (
    tester,
  ) async {
    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Chat'));
    await lockAndUnlock(tester);
    await letPopupsFinish(tester);
  });
}
