import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reacti_app/features/chat/logic/selfie_mirror.dart';

/// A 32x16 picture whose left half is red and right half is blue, so a
/// left-to-right flip is unmistakable even after JPEG loss.
img.Image _redLeftBlueRight() {
  final image = img.Image(width: 32, height: 16);
  for (final pixel in image) {
    if (pixel.x < 16) {
      pixel.setRgb(255, 0, 0);
    } else {
      pixel.setRgb(0, 0, 255);
    }
  }
  return image;
}

/// Whether the pixel at ([x], [y]) of [image] is clearly red rather than blue.
bool _isRed(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return pixel.r > 180 && pixel.b < 80;
}

/// Whether the pixel at ([x], [y]) of [image] is clearly blue rather than red.
bool _isBlue(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return pixel.b > 180 && pixel.r < 80;
}

void main() {
  group('mirrorJpeg', () {
    test('swaps the left and right sides of the picture', () {
      final jpeg = img.encodeJpg(_redLeftBlueRight(), quality: 100);

      final mirrored = img.decodeJpg(mirrorJpeg(jpeg))!;

      expect(mirrored.width, 32);
      expect(mirrored.height, 16);
      expect(_isBlue(mirrored, 4, 8), isTrue, reason: 'left is now blue');
      expect(_isRed(mirrored, 27, 8), isTrue, reason: 'right is now red');
    });

    test('mirrors a photo the camera stored sideways with a rotate tag', () {
      // How a phone really saves a portrait shot: pixels on their side plus
      // EXIF orientation 6 ("rotate 90 degrees to display"). Flipping the raw
      // pixels of such a file would turn the displayed photo upside down.
      final sideways = img.copyRotate(_redLeftBlueRight(), angle: -90);
      sideways.exif.imageIfd.orientation = 6;
      final jpeg = img.encodeJpg(sideways, quality: 100);
      // Guard the fixture: displayed upright it must be red-left, blue-right,
      // otherwise the assertions below prove nothing.
      final displayed = img.bakeOrientation(img.decodeJpg(jpeg)!);
      expect(displayed.width, 32);
      expect(_isRed(displayed, 4, 8), isTrue);

      final mirrored = img.decodeJpg(mirrorJpeg(jpeg))!;

      // Upright pixels, no leftover tag to rotate them a second time.
      final orientation = mirrored.exif.imageIfd.orientation;
      expect(orientation == null || orientation == 1, isTrue);
      expect(mirrored.width, 32);
      expect(mirrored.height, 16);
      expect(_isBlue(mirrored, 4, 8), isTrue, reason: 'left is now blue');
      expect(_isRed(mirrored, 27, 8), isTrue, reason: 'right is now red');
    });

    test('keeps the picture quality: same size, pixels within a hair', () {
      // A detailed picture (every pixel differs from its neighbours) is where
      // a lossy re-encode would show. Compare each mirrored pixel with the
      // pixel it came from.
      final detailed = img.Image(width: 64, height: 48);
      for (final pixel in detailed) {
        pixel.setRgb(pixel.x * 4, pixel.y * 5, (pixel.x * pixel.y) % 256);
      }
      final jpeg = img.encodeJpg(detailed, quality: 90);
      final source = img.decodeJpg(jpeg)!;

      final mirrored = img.decodeJpg(mirrorJpeg(jpeg))!;

      expect(mirrored.width, source.width);
      expect(mirrored.height, source.height);
      var worst = 0;
      for (final pixel in mirrored) {
        final from = source.getPixel(source.width - 1 - pixel.x, pixel.y);
        for (final diff in [
          pixel.r - from.r,
          pixel.g - from.g,
          pixel.b - from.b,
        ]) {
          if (diff.abs() > worst) worst = diff.abs().toInt();
        }
      }
      // Out of 255 levels per colour; a visible loss is in the tens.
      expect(worst, lessThanOrEqualTo(4));
    });

    test('rejects bytes that are not a JPEG', () {
      expect(
        () => mirrorJpeg(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(anything),
      );
    });
  });

  group('photoMatchingPreview', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('selfie_mirror'));
    tearDown(() => dir.deleteSync(recursive: true));

    /// Writes the red-left / blue-right picture to disk as a captured shot.
    XFile shotOnDisk() {
      final file = File('${dir.path}/CAP_test.jpg');
      file.writeAsBytesSync(img.encodeJpg(_redLeftBlueRight(), quality: 100));
      return XFile(file.path);
    }

    test('a front-lens photo comes back mirrored, in a new file', () async {
      final shot = shotOnDisk();
      final before = await shot.readAsBytes();

      final result = await photoMatchingPreview(
        shot,
        CameraLensDirection.front,
      );

      expect(result.path, isNot(shot.path));
      final mirrored = img.decodeJpg(await result.readAsBytes())!;
      expect(_isBlue(mirrored, 4, 8), isTrue);
      expect(_isRed(mirrored, 27, 8), isTrue);
      // The original is left alone, so a failure half-way can fall back to it.
      expect(await shot.readAsBytes(), before);
    });

    test('a back-lens photo is handed on untouched', () async {
      final shot = shotOnDisk();

      final result = await photoMatchingPreview(shot, CameraLensDirection.back);

      expect(result, same(shot));
      expect(dir.listSync(), hasLength(1));
    });

    test('an external-lens photo is handed on untouched', () async {
      final shot = shotOnDisk();

      final result = await photoMatchingPreview(
        shot,
        CameraLensDirection.external,
      );

      expect(result, same(shot));
    });

    test('keeps the original photo when it cannot be mirrored', () async {
      final file = File('${dir.path}/CAP_broken.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);
      final shot = XFile(file.path);

      final result = await photoMatchingPreview(
        shot,
        CameraLensDirection.front,
      );

      expect(result, same(shot));
    });
  });
}
