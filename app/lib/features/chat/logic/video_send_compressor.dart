import 'package:camera/camera.dart';
import 'package:video_compress/video_compress.dart';

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

/// Returns the file to actually upload for a message of [mediaType].
///
/// Videos are compressed via [videoSendCompressor] for smooth recipient
/// playback; images/text (or a null [file]) are returned unchanged. Never
/// throws and never blocks the send — on any compression failure the original
/// [file] is returned so the message still goes out.
Future<XFile?> prepareVideoForSend(XFile? file, String mediaType) async {
  // ponytail: always transcode a video (even an already-small one) — detecting
  // "already optimized" isn't worth the code, and MediumQuality is quick.
  if (file == null || mediaType != 'video') return file;
  try {
    return await videoSendCompressor.compress(file);
  } catch (_) {
    return file;
  }
}
