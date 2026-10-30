// App Lock: leave the app, come back, and it is locked until the phone's own
// unlock passes (a PIN on Android, Face ID on the iPhone simulator, both
// worked by the host). Driven by the testing lab
// (.github/workflows/testing-lab.yml).

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/main.dart' as app;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/host.dart';
import 'support/wait.dart';

/// Prints each app lifecycle change, so a lock that never comes shows
/// whether the app ever went to the background.
class _LifecycleLog with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      debugPrint('lifecycle: $state');
}

/// Leaves the app with App Lock on, comes back, and unlocks it.
Future<void> lockAndUnlock(WidgetTester tester) async {
  final lifecycle = _LifecycleLog();
  WidgetsBinding.instance.addObserver(lifecycle);
  addTearDown(() => WidgetsBinding.instance.removeObserver(lifecycle));
  askHost('lock-setup');
  final storage = GetStorage();
  await storage.write(kKeyAppLockEnabled, true);
  await storage.write(kKeyAppLockDelay, 'immediately');

  askHost('home');
  // No frames while backgrounded: wait in plain time, not with pump.
  await Future<void>.delayed(const Duration(seconds: 3));
  askHost('launch');
  await pumpUntilFound(tester, find.text('Reacti is locked'));

  await tester.tap(find.text('Unlock'));
  // The phone's own unlock screen: Flutter cannot see it, the host passes it.
  askHost('unlock');
  await waitFor(
    () async => find.text('Reacti is locked').evaluate().isEmpty,
    what: 'the PIN to unlock the app',
    tester: tester,
  );
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
