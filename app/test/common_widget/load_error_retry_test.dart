// Unit tests for LoadErrorRetry — the shared "couldn't load" state shown when
// a screen's data stream errors (instead of a blank screen).

import 'package:reacti_app/common_widget/load_error_retry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/widget_harness.dart';

void main() {
  testWidgets('renders the message and a Retry button', (tester) async {
    await pumpInApp(
      tester,
      LoadErrorRetry(message: 'Could not load.', onRetry: () {}),
    );

    expect(find.text('Could not load.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry invokes onRetry', (tester) async {
    var taps = 0;
    await pumpInApp(
      tester,
      LoadErrorRetry(message: 'Could not load.', onRetry: () => taps++),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(taps, 1);
  });
}
