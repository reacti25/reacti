// Waiting helpers for device tests. The app never settles (spinners, shimmer,
// the looping demo video), so pumpAndSettle would hang: poll instead.

import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

/// Polls [condition] until it holds, failing with [what] after [timeout].
/// On a timeout the host first screenshots the device, so the lab's logs
/// show what was on screen instead.
///
/// Pass [tester] to keep frames pumping while waiting (a running app);
/// leave it null for checks that need no UI (permissions, the server).
Future<void> waitFor(
  Future<bool> Function() condition, {
  required String what,
  WidgetTester? tester,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      askHost('screenshot');
      // Plain time: the host needs a moment before the test ends.
      await Future<void>.delayed(const Duration(seconds: 3));
      fail('timed out waiting for $what');
    }
    if (tester != null) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
}

/// Pumps the app until [finder] matches at least one widget.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 90),
}) => waitFor(
  () async {
    try {
      return finder.evaluate().isNotEmpty;
    } on TypeError {
      // Mid route change an element can be half torn down; look again.
      return false;
    }
  },
  // Described, not evaluated: toString() would search the tree right now.
  what: finder.describeMatch(Plurality.many),
  tester: tester,
  timeout: timeout,
);

/// Pumps real time until the app's pop-up messages (Get snackbars, about 3s
/// each) have finished: a test that ends with one animating fails.
Future<void> letPopupsFinish(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}
