// Pins the prefetch decision (branch 2.2 of
// docs/PLAN-media-timing-and-speed-2026-06-23.md): images prefetch on any
// connection, videos on any live connection (only skipped offline, since they
// are compressed on send and the warm is a light init), and nothing for
// local/optimistic paths. The actual cache warming is a side effect; only the
// decision is unit-tested.

import 'package:reacti_app/helpers/media_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaPrefetch.decide', () {
    test('a remote image prefetches on any network', () {
      for (final net in ['wifi', 'cellular', 'unknown']) {
        expect(
          MediaPrefetch.decide(
            file: 'https://cdn.example/p.jpg',
            mediaType: 'image',
            network: net,
          ),
          PrefetchAction.image,
          reason: 'images are small — prefetch regardless of network ($net)',
        );
      }
    });

    test('a remote video prefetches on any live connection', () {
      for (final net in ['wifi', 'cellular', 'unknown']) {
        expect(
          MediaPrefetch.decide(
            file: 'https://cdn.example/v.mp4',
            mediaType: 'video',
            network: net,
          ),
          PrefetchAction.video,
          reason: 'compressed videos warm cheaply — prefetch off Wi-Fi ($net)',
        );
      }
    });

    test('a remote video is not prefetched while offline', () {
      expect(
        MediaPrefetch.decide(
          file: 'https://cdn.example/v.mp4',
          mediaType: 'video',
          network: 'none',
        ),
        PrefetchAction.none,
      );
    });

    test('a local / optimistic (non-http) path is never prefetched', () {
      expect(
        MediaPrefetch.decide(
          file: '/data/user/0/app/cache/local.jpg',
          mediaType: 'image',
          network: 'wifi',
        ),
        PrefetchAction.none,
      );
    });

    test('a null file or unknown media type is a no-op', () {
      expect(
        MediaPrefetch.decide(file: null, mediaType: 'image', network: 'wifi'),
        PrefetchAction.none,
      );
      expect(
        MediaPrefetch.decide(
          file: 'https://cdn.example/x',
          mediaType: 'text',
          network: 'wifi',
        ),
        PrefetchAction.none,
      );
    });
  });
}
