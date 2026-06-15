// Tests for the size/media-kind bucketing helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_buckets.dart';

void main() {
  group('sizeBucket', () {
    test('maps bytes to the catalog buckets at the boundaries', () {
      expect(sizeBucket(0), 'xs');
      expect(sizeBucket(256 * 1024 - 1), 'xs');
      expect(sizeBucket(256 * 1024), 'sm');
      expect(sizeBucket(1024 * 1024 - 1), 'sm');
      expect(sizeBucket(1024 * 1024), 'md');
      expect(sizeBucket(5 * 1024 * 1024 - 1), 'md');
      expect(sizeBucket(5 * 1024 * 1024), 'lg');
      expect(sizeBucket(20 * 1024 * 1024 - 1), 'lg');
      expect(sizeBucket(20 * 1024 * 1024), 'xl');
    });
  });

  group('mediaKindFromPath', () {
    test('classifies images and videos by extension', () {
      expect(mediaKindFromPath('a/b/photo.JPG'), 'image');
      expect(mediaKindFromPath('reaction.mp4'), 'video');
      expect(mediaKindFromPath('clip.mov'), 'video');
    });

    test('returns null for unknown or extension-less paths', () {
      expect(mediaKindFromPath('file.txt'), isNull);
      expect(mediaKindFromPath('noextension'), isNull);
    });
  });
}
