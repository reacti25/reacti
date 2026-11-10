import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// JPEG quality of the re-encoded selfie.
///
/// High on purpose: this is a second encode of a photo the send path will
/// compress again, so anything lower stacks visible loss on a face.
const int _mirroredJpegQuality = 95;

/// Returns [jpeg] flipped left-to-right, as a viewer sees it.
///
/// The camera's EXIF rotation is baked into the pixels first. A phone stores a
/// portrait shot sideways plus a "rotate me" tag, so flipping the raw pixels
/// left-to-right would turn the displayed photo upside down instead.
///
/// Throws a [FormatException] when [jpeg] cannot be decoded as a JPEG.
Uint8List mirrorJpeg(Uint8List jpeg) {
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) throw const FormatException('Not a decodable JPEG');
  final upright = img.bakeOrientation(decoded);
  return img.encodeJpg(
    img.flipHorizontal(upright),
    quality: _mirroredJpegQuality,
  );
}

/// The photo to hand on for a [shot] taken with [lens]: what the user framed.
///
/// The live preview of a front lens is a mirror, but the camera plugin saves
/// the photo un-mirrored, so the picture visibly jumped to the other side the
/// moment the shutter fired. A front-lens shot is therefore mirrored back to
/// match the preview and returned as a new file beside the original. Any other
/// lens previews un-mirrored already, so its shot is returned untouched.
///
/// Never loses the photo: if the mirroring fails (unreadable file, a format
/// that is not JPEG, a full disk) the original [shot] is returned instead.
///
/// Videos need no such step on iOS, where the plugin records the mirrored
/// preview frames themselves.
///
/// ponytail: a pure-Dart flip in a background isolate. Fine for the 720p photo
/// `ResolutionPreset.high` yields; move to a native flip if the preset is ever
/// raised to full sensor size and the pause before the editor becomes visible.
Future<XFile> photoMatchingPreview(XFile shot, CameraLensDirection lens) async {
  if (lens != CameraLensDirection.front) return shot;
  try {
    final mirrored = await compute(mirrorJpeg, await shot.readAsBytes());
    final out = File('${shot.path}_mirrored.jpg');
    await out.writeAsBytes(mirrored, flush: true);
    return XFile(out.path);
  } catch (e) {
    log('selfie_mirror: kept the un-mirrored photo, mirroring failed: $e');
    return shot;
  }
}
