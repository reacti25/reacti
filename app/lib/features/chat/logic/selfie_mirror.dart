import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// JPEG quality of the re-encoded selfie: the maximum.
///
/// The mirrored photo must look the same as the one the camera took. Mirroring
/// means decoding and encoding again, and at 100 (with the encoder's default of
/// full colour resolution) that round trip changes a pixel by a few levels out
/// of 255 at most, which nobody can see. The dimensions are unchanged; the
/// send path still does its own compression afterwards, exactly as before.
const int _mirroredJpegQuality = 100;

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
/// Videos need no such step: iOS records the mirrored preview frames
/// themselves, and Android is told to by [setFrontVideoMirrored].
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

/// Channel to `FrontVideoMirror` in the Android app, which owns the switch.
const MethodChannel _frontVideoMirror = MethodChannel(
  'reacti/front_video_mirror',
);

/// Tells the Android camera whether the next camera it builds should record
/// front-lens video mirrored, the way the preview shows it.
///
/// Android only: CameraX records a selfie video un-mirrored by default, so it
/// jumped to the other side once recorded. iOS already records the mirrored
/// preview frames, so this does nothing there.
///
/// The setting is read once, while a camera is being built. Switch it on just
/// before `CameraController.initialize()` and off straight after, so no other
/// camera (the silent reaction recorder in particular) is built while it is on.
///
/// Never throws: if the switch cannot be reached the video records un-mirrored,
/// as it did before, which is a worse picture but not a lost one.
Future<void> setFrontVideoMirrored(bool enabled) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _frontVideoMirror.invokeMethod<void>('setEnabled', enabled);
  } catch (e) {
    log('selfie_mirror: could not switch front video mirroring: $e');
  }
}
