// Pins the decode-sizing optimization (branch 2.3 of
// docs/PLAN-media-timing-and-speed-2026-06-23.md): InboxCustomNetworkImage must
// cap the in-memory decode to the screen width in physical pixels, so chat
// media isn't decoded at full source resolution. A regression here brings back
// the memory/jank/paint-latency cost the cap removes.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:reacti_app/common_widget/inbox_custom_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thumbhash/flutter_thumbhash.dart';

void main() {
  testWidgets('caps memCacheWidth to screen-width in physical pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(400, 800), devicePixelRatio: 2.0),
          child: InboxCustomNetworkImage(urls: 'https://example.invalid/p.jpg'),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    // 400 logical width * 2.0 devicePixelRatio = 800 physical pixels.
    expect(image.memCacheWidth, 800);
  });

  testWidgets('leaves height to scale with aspect ratio (no memCacheHeight)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(400, 800), devicePixelRatio: 2.0),
          child: InboxCustomNetworkImage(urls: 'https://example.invalid/p.jpg'),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.memCacheHeight, isNull);
  });

  test('a backend-produced ThumbHash decodes to an ImageProvider (interop)', () {
    // This exact string was produced by the PHP encoder (srwiez/thumbhash) in
    // ThumbHashServiceTest; decoding it here proves the backend→app placeholder
    // contract — the hash the server stores is renderable by the client.
    final provider =
        ThumbHash.fromBase64('XmUFRYYHuHd3eIeAfYV4ewd3cHAH').toImage();
    expect(provider, isA<ImageProvider>());
  });
}
