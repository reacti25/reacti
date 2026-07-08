// Tests for prepareMediaForSend: videos and images are each compressed via
// their own seam; text/null pass through; and any compression failure falls
// back to the original file so a send is never blocked.

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/video_send_compressor.dart';

/// Fake video compressor: records calls, returns a distinct path.
class _FakeVideoCompressor implements VideoSendCompressor {
  int calls = 0;

  @override
  Future<XFile> compress(XFile file) async {
    calls++;
    return XFile('${file.path}.compressed.mp4');
  }
}

/// Fake image compressor: records calls, returns a distinct path.
class _FakeImageCompressor implements ImageSendCompressor {
  int calls = 0;

  @override
  Future<XFile> compress(XFile file) async {
    calls++;
    return XFile('${file.path}.compressed.jpg');
  }
}

class _ThrowingVideoCompressor implements VideoSendCompressor {
  @override
  Future<XFile> compress(XFile file) async => throw StateError('encoder down');
}

class _ThrowingImageCompressor implements ImageSendCompressor {
  @override
  Future<XFile> compress(XFile file) async => throw StateError('encoder down');
}

void main() {
  late VideoSendCompressor originalVideo;
  late ImageSendCompressor originalImage;
  late _FakeVideoCompressor video;
  late _FakeImageCompressor image;

  setUp(() {
    originalVideo = videoSendCompressor;
    originalImage = imageSendCompressor;
    video = _FakeVideoCompressor();
    image = _FakeImageCompressor();
    videoSendCompressor = video;
    imageSendCompressor = image;
  });

  tearDown(() {
    videoSendCompressor = originalVideo;
    imageSendCompressor = originalImage;
  });

  test('compresses a video before sending', () async {
    final result = await prepareMediaForSend(XFile('/tmp/clip.mp4'), 'video');

    expect(video.calls, 1);
    expect(image.calls, 0);
    expect(result!.path, '/tmp/clip.mp4.compressed.mp4');
  });

  test('compresses an image before sending', () async {
    final result = await prepareMediaForSend(XFile('/tmp/photo.jpg'), 'image');

    expect(image.calls, 1);
    expect(video.calls, 0);
    expect(result!.path, '/tmp/photo.jpg.compressed.jpg');
  });

  test('leaves text (and other types) untouched', () async {
    final result = await prepareMediaForSend(XFile('/tmp/note.txt'), 'text');

    expect(video.calls, 0);
    expect(image.calls, 0);
    expect(result!.path, '/tmp/note.txt');
  });

  test('returns null when there is no file', () async {
    expect(await prepareMediaForSend(null, 'image'), isNull);
    expect(image.calls, 0);
  });

  test('falls back to the original when video compression throws', () async {
    videoSendCompressor = _ThrowingVideoCompressor();

    final result = await prepareMediaForSend(XFile('/tmp/clip.mp4'), 'video');

    expect(result!.path, '/tmp/clip.mp4');
  });

  test('falls back to the original when image compression throws', () async {
    imageSendCompressor = _ThrowingImageCompressor();

    final result = await prepareMediaForSend(XFile('/tmp/photo.jpg'), 'image');

    // A send must never be blocked by a compression failure.
    expect(result!.path, '/tmp/photo.jpg');
  });
}
