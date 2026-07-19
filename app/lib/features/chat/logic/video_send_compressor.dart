import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

import '../../../analytics/analytics_buckets.dart';
import '../../../analytics/analytics_locator.dart';
import '../../../analytics/events.dart';

/// Shrinks a picked video before it is uploaded, so the recipient's playback
/// starts fast and never stalls to re-buffer.
///
/// The recipient's chat serves raw uploads as static files; a full-resolution
/// phone clip is too heavy to stream smoothly on mobile, so it freezes to
/// buffer mid-play. Compressing on send (WhatsApp-style) makes every uploaded
/// video small and web-playable — the cost is a moment on the sender's device,
/// paid once, off the critical UI path.
///
/// Exposed as a seam (not a bare function) so tests can swap in a fake without
/// invoking the native encoder — mirrors the `reactionRecorder` pattern.
abstract class VideoSendCompressor {
  /// Returns a compressed copy of [file], or [file] itself if the encoder
  /// produced nothing. May throw; callers treat any failure as "send original".
  Future<XFile> compress(XFile file);
}

/// Real compressor backed by the `video_compress` plugin.
class RealVideoSendCompressor implements VideoSendCompressor {
  @override
  Future<XFile> compress(XFile file) async {
    // MediumQuality ≈ 720p H.264 — a large drop in bytes for little visible
    // quality loss, producing a web-playable MP4 that streams smoothly on
    // mobile networks.
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false, // keep the original for the local optimistic preview
      includeAudio: true,
    );
    final path = info?.path;
    return path == null ? file : XFile(path);
  }
}

/// Swappable compressor instance; tests replace it with a fake. Mirrors the
/// `reactionRecorder` global-seam pattern used elsewhere in chat.
VideoSendCompressor videoSendCompressor = RealVideoSendCompressor();

/// Shrinks a picked photo before upload, so recipients download a web-sized
/// image instead of a multi-megapixel phone original. Client-side (never
/// touches the stored file server-side), and fail-safe.
abstract class ImageSendCompressor {
  /// Returns a compressed copy of [file], or [file] itself if the encoder
  /// produced nothing. May throw; callers treat any failure as "send original".
  Future<XFile> compress(XFile file);
}

/// Real image compressor backed by the `flutter_image_compress` plugin.
class RealImageSendCompressor implements ImageSendCompressor {
  @override
  Future<XFile> compress(XFile file) async {
    // Cap the longest edge at 1600px and re-encode JPEG q85 — a large byte
    // drop with no visible loss at chat sizes. Writes to a temp path (the
    // plugin requires a distinct target); the original stays for the local
    // optimistic preview.
    final target =
        '${Directory.systemTemp.path}/reacti_c_'
        '${file.name.hashCode}_${file.path.length}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
    );
    return result ?? file;
  }
}

/// Swappable image compressor; tests replace it with a fake.
ImageSendCompressor imageSendCompressor = RealImageSendCompressor();

/// Returns the file to actually upload for a message of [mediaType].
///
/// Videos are compressed for smooth playback and images are downscaled to a
/// web size; text (or a null [file]) is returned unchanged. Never throws and
/// never blocks the send — on any compression failure the original [file] is
/// returned so the message still goes out.
Future<XFile?> prepareMediaForSend(XFile? file, String mediaType) async {
  // ponytail: always re-encode media (even an already-small one) — detecting
  // "already optimized" isn't worth the code, and both encoders are quick.
  if (file == null) return file;
  if (mediaType != 'video' && mediaType != 'image') return file;

  // Time the compression so its cost is measurable — `send_ms`/`upload_ms` only
  // cover the HTTP call, so this on-device step is otherwise an invisible delay.
  final sw = Stopwatch()..start();
  try {
    final out =
        mediaType == 'video'
            ? await videoSendCompressor.compress(file)
            : await imageSendCompressor.compress(file);
    sw.stop();
    _trackCompressed(sw.elapsedMilliseconds, mediaType, out, 'success');
    return out;
  } catch (_) {
    sw.stop();
    _trackCompressed(sw.elapsedMilliseconds, mediaType, null, 'failure');
    return file;
  }
}

/// Emits `media_compressed` with the measured [compressMs]. Fire-and-forget: the
/// output-size read is detached so instrumenting never delays the send that is
/// waiting on this compression. Never throws.
void _trackCompressed(
  int compressMs,
  String mediaType,
  XFile? out,
  String result,
) {
  () async {
    // Best-effort size read — a failure here must not drop the timing signal.
    int? bytes;
    try {
      bytes = out == null ? null : await out.length();
    } catch (_) {
      bytes = null;
    }
    try {
      analytics.track(Events.mediaCompressed, {
        Props.compressMs: compressMs,
        Props.mediaKind: mediaType,
        if (bytes != null) Props.sizeBucket: sizeBucket(bytes),
        Props.result: result,
      });
    } catch (_) {
      // Analytics must never break a send.
    }
  }();
}
