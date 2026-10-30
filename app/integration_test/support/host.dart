// Lets a device test ask the computer running it to act on the device, for
// what Dart on the device cannot do (place a phone call, open a link from
// outside the app, cut the network, pass the phone's own unlock screen). The
// lab's runner scripts read the test's output and carry out each request with
// their platform's tool: .github/scripts/android_e2e.sh (adb) and
// .github/scripts/ios_e2e.sh (simctl).

import 'package:flutter/foundation.dart';

/// Asks the host to do [action] on this device. Actions both runners know:
///
///   * `call`, `hangup`: an answered incoming phone call (Android only).
///   * `open <url>`: open a link from outside the app.
///   * `offline`, `online`: make the test server unreachable, then back.
///   * `lock-setup`: give the phone a screen lock (PIN, or Face ID).
///   * `unlock`: pass the phone's own unlock screen.
///   * `home`, `launch`: leave the app, then bring it back.
///   * `screenshot`: save the screen with the lab's logs.
///
/// Fire and forget: poll for the effect afterwards (see `waitFor`).
void askHost(String action) => debugPrint('E2E_HOST: $action');
