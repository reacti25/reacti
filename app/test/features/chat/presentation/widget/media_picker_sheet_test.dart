// Widget tests for MediaPickerSheet — the options-list attachment-source
// bottom sheet shared by InboxScreen and GroupInboxScreen.

import 'package:reacti_app/features/chat/presentation/widget/media_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('MediaPickerSheet', () {
    /// Builds a Gallery/Camera sheet whose callbacks record which row fired.
    MediaPickerSheet sheetRecording(List<String> log) {
      return MediaPickerSheet(
        options: [
          MediaPickerOption('Gallery', () => log.add('gallery')),
          MediaPickerOption('Camera', () => log.add('camera')),
        ],
      );
    }

    testWidgets('renders each option label', (tester) async {
      await pumpInApp(tester, sheetRecording([]));

      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
    });

    testWidgets('each option invokes only its own callback', (tester) async {
      final log = <String>[];
      await pumpInApp(tester, sheetRecording(log));

      await tester.tap(find.text('Gallery'));
      await tester.tap(find.text('Camera'));

      expect(log, ['gallery', 'camera']);
    });
  });
}
