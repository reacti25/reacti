// Widget tests for MediaPickerSheet — the options-list attachment-source
// bottom sheet shared by InboxScreen and GroupInboxScreen.

import 'package:flutter/material.dart';
import 'package:reacti_app/features/chat/presentation/widget/media_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('MediaPickerSheet', () {
    /// Builds a Gallery/Camera sheet whose callbacks record which one fired.
    MediaPickerSheet sheetRecording(List<String> log) {
      return MediaPickerSheet(
        options: [
          MediaPickerOption(
            'Gallery',
            () => log.add('gallery'),
            icon: Icons.photo_library_rounded,
          ),
          MediaPickerOption(
            'Camera',
            () => log.add('camera'),
            icon: Icons.photo_camera_rounded,
          ),
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
