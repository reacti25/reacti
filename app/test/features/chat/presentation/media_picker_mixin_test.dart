// Unit tests for isVideoMedia — the classifier that decides whether a file
// picked via image_picker's pickMedia (image *or* video in one flow) should be
// staged as 'video' or 'image'.

import 'package:reacti_app/features/chat/presentation/media_picker_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isVideoMedia', () {
    test('MIME type is authoritative when present', () {
      // Trust the MIME type even when the extension disagrees.
      expect(isVideoMedia('clip.jpg', mimeType: 'video/mp4'), isTrue);
      expect(isVideoMedia('frame.mp4', mimeType: 'image/jpeg'), isFalse);
    });

    test('falls back to the file extension when MIME is absent', () {
      expect(isVideoMedia('holiday.MOV'), isTrue);
      expect(isVideoMedia('holiday.mp4'), isTrue);
      expect(isVideoMedia('selfie.jpg'), isFalse);
      expect(isVideoMedia('selfie.png'), isFalse);
    });

    test('treats an unknown or missing extension as an image', () {
      expect(isVideoMedia('noextension'), isFalse);
      expect(isVideoMedia('archive.zip'), isFalse);
    });
  });
}
