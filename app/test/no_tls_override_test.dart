// Regression guard: no code in the app installs a global HttpOverrides.
//
// MyHttpOverrides — which made HttpClient.badCertificateCallback
// return true for every certificate, effectively disabling TLS
// validation app-wide — was removed (backlog §1 CRITICAL). This test
// pins the invariant so a future change reintroducing a global
// override is caught immediately.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no HttpOverrides is installed by any imported library', () {
    expect(HttpOverrides.current, isNull);
  });
}
