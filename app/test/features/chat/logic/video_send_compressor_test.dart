// Tests for prepareVideoForSend: only videos are compressed, and compression
// never blocks or breaks a send (failures fall back to the original file).

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/video_send_compressor.dart';

/// Records calls and returns a distinct compressed path so tests can tell the
/// compressed file apart from the original.
class _FakeCompressor implements VideoSendCompressor {
  int calls = 0;

  @override
  Future<XFile> compress(XFile file) async {
    calls++;
    return XFile('${file.path}.compressed.mp4');
  }
}

/// Always throws, to exercise the fail-safe path.
class _ThrowingCompressor implements VideoSendCompressor {
  @override
  Future<XFile> compress(XFile file) async => throw StateError('encoder down');
}

void main() {
  late VideoSendCompressor original;

  setUp(() => original = videoSendCompressor);
  tearDown(() => videoSendCompressor = original);

  test('compresses a video before sending', () async {
    final fake = _FakeCompressor();
    videoSendCompressor = fake;

    final result = await prepareVideoForSend(XFile('/tmp/clip.mp4'), 'video');

    expect(fake.calls, 1);
    expect(result!.path, '/tmp/clip.mp4.compressed.mp4');
  });

  test('leaves an image untouched', () async {
    final fake = _FakeCompressor();
    videoSendCompressor = fake;

    final result = await prepareVideoForSend(XFile('/tmp/photo.jpg'), 'image');

    expect(fake.calls, 0);
    expect(result!.path, '/tmp/photo.jpg');
  });

  test('returns null when there is no file', () async {
    final fake = _FakeCompressor();
    videoSendCompressor = fake;

    expect(await prepareVideoForSend(null, 'video'), isNull);
    expect(fake.calls, 0);
  });

  test('falls back to the original file when compression throws', () async {
    videoSendCompressor = _ThrowingCompressor();

    final result = await prepareVideoForSend(XFile('/tmp/clip.mp4'), 'video');

    // The send must still go out with the original, never blocked by a
    // compression failure.
    expect(result!.path, '/tmp/clip.mp4');
  });
}
