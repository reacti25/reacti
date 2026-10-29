// Lets a device test ask the computer running it to act on the device, for
// what Dart on the device cannot do (place a phone call, open a link from
// outside the app, cut the network). The runner script
// (.github/scripts/android_e2e.sh) reads the test's output and runs
// `adb <args>` for every request line.

import 'package:flutter/foundation.dart';

/// Asks the host to run `adb <adbArgs>` against this emulator.
///
/// Fire and forget: poll for the effect afterwards (see `waitFor`).
/// Example: `askHost('emu gsm call 5551234')`.
void askHost(String adbArgs) => debugPrint('E2E_HOST: $adbArgs');
