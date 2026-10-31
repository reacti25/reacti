// Which screen the app opens on. That the choice is made once, so signing in
// cannot build a second home screen under the first, is checked on devices by
// the testing lab (integration_test/first_run_test.dart: the demo opens once).

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/loading.dart';

void main() {
  test('the very first run opens on the welcome screen', () {
    expect(
      startScreenFor(firstTime: true, loggedIn: false),
      StartScreen.welcome,
    );
  });

  test('a saved session opens on the home screen', () {
    expect(startScreenFor(firstTime: false, loggedIn: true), StartScreen.home);
  });

  test('otherwise the app opens on login', () {
    expect(
      startScreenFor(firstTime: false, loggedIn: false),
      StartScreen.login,
    );
  });
}
