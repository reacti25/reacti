// The update prompt: shown once per run when the server's newest version for
// this platform is newer than the app's own; "Update" opens the store link,
// "Not now" just closes it; nothing at all when there is no newer version or
// the lookup fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/update_prompt/update_prompt.dart';

void main() {
  group('isNewer', () {
    test('compares number by number, not as text', () {
      expect(UpdatePrompt.isNewer('1.10.0', '1.9.9'), isTrue);
      expect(UpdatePrompt.isNewer('1.8.4', '1.8.3'), isTrue);
      expect(UpdatePrompt.isNewer('2.0', '1.9.9'), isTrue);
    });

    test('the same or an older version is not newer', () {
      expect(UpdatePrompt.isNewer('1.8.3', '1.8.3'), isFalse);
      expect(UpdatePrompt.isNewer('1.8', '1.8.0'), isFalse);
      expect(UpdatePrompt.isNewer('1.8.2', '1.8.3'), isFalse);
    });

    test('anything that is not a version is never newer', () {
      expect(UpdatePrompt.isNewer('', '1.8.3'), isFalse);
      expect(UpdatePrompt.isNewer('v2 beta', '1.8.3'), isFalse);
    });
  });

  group('the dialog', () {
    late List<Uri> opened;

    setUp(() {
      UpdatePrompt.debugReset();
      opened = [];
      UpdatePrompt.currentVersion = () async => '1.8.3';
      UpdatePrompt.openStore = (uri) async {
        opened.add(uri);
        return true;
      };
    });

    /// A screen whose button asks, as the home screen does on opening.
    Future<void> ask(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => UpdatePrompt.showIfOutdated(context),
                  child: const Text('open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a newer version offers to update; Update opens the store', (
      tester,
    ) async {
      UpdatePrompt.lookup =
          () async => (version: '1.8.4', url: 'https://apps.apple.com/app/id1');

      await ask(tester);
      expect(find.byKey(const Key('update-prompt')), findsOneWidget);
      expect(find.text('A new version of Reacti is out'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://apps.apple.com/app/id1')]);
      expect(find.byKey(const Key('update-prompt')), findsNothing);
    });

    testWidgets('Not now closes it without opening anything, and it does not '
        'come back until the next run', (tester) async {
      UpdatePrompt.lookup = () async => (version: '1.9.0', url: 'u://x');

      await ask(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-prompt')), findsNothing);
      expect(opened, isEmpty);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-prompt')), findsNothing);
    });

    testWidgets('the same version shows nothing', (tester) async {
      UpdatePrompt.lookup = () async => (version: '1.8.3', url: 'u://x');

      await ask(tester);

      expect(find.byKey(const Key('update-prompt')), findsNothing);
    });

    testWidgets('no version from the server shows nothing', (tester) async {
      UpdatePrompt.lookup = () async => null;

      await ask(tester);

      expect(find.byKey(const Key('update-prompt')), findsNothing);
    });

    testWidgets('a failed lookup shows nothing and throws nothing', (
      tester,
    ) async {
      UpdatePrompt.lookup = () async => throw Exception('offline');

      await ask(tester);

      expect(find.byKey(const Key('update-prompt')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
