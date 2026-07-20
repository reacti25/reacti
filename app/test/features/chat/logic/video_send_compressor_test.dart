// Tests for prepareMediaForSend: videos and images are each compressed via
// their own seam; text/null pass through; and any compression failure falls
// back to the original file so a send is never blocked.

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/features/chat/logic/video_send_compressor.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../../support/fake_analytics_service.dart';

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
  late FakeAnalyticsService analytics;

  setUp(() {
    originalVideo = videoSendCompressor;
    originalImage = imageSendCompressor;
    video = _FakeVideoCompressor();
    image = _FakeImageCompressor();
    videoSendCompressor = video;
    imageSendCompressor = image;

    analytics = FakeAnalyticsService();
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    videoSendCompressor = originalVideo;
    imageSendCompressor = originalImage;
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
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

  test('emits media_compressed with compress_ms for an image', () async {
    await prepareMediaForSend(XFile('/tmp/photo.jpg'), 'image');
    await _untilTracked(analytics);

    final props = analytics.propsOf(Events.mediaCompressed)!;
    expect(props[Props.mediaKind], 'image');
    expect(props[Props.result], 'success');
    expect(props[Props.compressMs], isA<int>());
  });

  test(
    'emits media_compressed result=failure when compression throws',
    () async {
      videoSendCompressor = _ThrowingVideoCompressor();

      await prepareMediaForSend(XFile('/tmp/clip.mp4'), 'video');
      await _untilTracked(analytics);

      final props = analytics.propsOf(Events.mediaCompressed)!;
      expect(props[Props.mediaKind], 'video');
      expect(props[Props.result], 'failure');
      expect(props[Props.compressMs], isA<int>());
    },
  );
}

/// Waits for the fire-and-forget `media_compressed` event to be emitted. The
/// tracking closure is detached and does a best-effort (async) file-size read
/// first, so it can take more than one microtask to land under load — poll
/// instead of a single `Duration.zero` tick, which is flaky in a full run.
Future<void> _untilTracked(FakeAnalyticsService analytics) async {
  for (var i = 0; i < 100; i++) {
    if (analytics.countOf(Events.mediaCompressed) > 0) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
