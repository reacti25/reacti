// Widget tests for MediaPickerSheet — the four-option attachment-source
// bottom sheet shared by InboxScreen and GroupInboxScreen.

import 'package:achiar_expert_app/features/chat/presentation/widget/media_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/widget_harness.dart';

void main() {
  group('MediaPickerSheet', () {
    /// Builds a sheet whose four callbacks record which one fired.
    MediaPickerSheet sheetRecording(List<String> log) {
      return MediaPickerSheet(
        onPickGalleryImage: () => log.add('gallery-image'),
        onPickCameraImage: () => log.add('camera-image'),
        onPickGalleryVideo: () => log.add('gallery-video'),
        onPickCameraVideo: () => log.add('camera-video'),
      );
    }

    testWidgets('renders the four source options', (tester) async {
      await pumpInApp(tester, sheetRecording([]));

      expect(find.text('Pick Image from Gallery'), findsOneWidget);
      expect(find.text('Pick Image from Camera'), findsOneWidget);
      expect(find.text('Pick Video from Gallery'), findsOneWidget);
      expect(find.text('Pick Video from Camera'), findsOneWidget);
    });

    testWidgets('each option invokes only its own callback', (tester) async {
      final log = <String>[];
      await pumpInApp(tester, sheetRecording(log));

      await tester.tap(find.text('Pick Image from Gallery'));
      await tester.tap(find.text('Pick Image from Camera'));
      await tester.tap(find.text('Pick Video from Gallery'));
      await tester.tap(find.text('Pick Video from Camera'));

      expect(log, [
        'gallery-image',
        'camera-image',
        'gallery-video',
        'camera-video',
      ]);
    });
  });
}
