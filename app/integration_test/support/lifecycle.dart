// Prints the app's lifecycle changes into a device test's log, so a journey
// that loses the app (backgrounded, locked) shows when and how.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _LifecycleLog with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      debugPrint('lifecycle: $state');
}

/// Logs each lifecycle change until the current test ends.
void logLifecycle() {
  final log = _LifecycleLog();
  WidgetsBinding.instance.addObserver(log);
  addTearDown(() => WidgetsBinding.instance.removeObserver(log));
}
