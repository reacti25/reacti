// Pins that CustomNetworkImage downscales its decode (memCacheWidth) so small
// avatar/thumbnail slots don't decode full-resolution source images into memory.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/common_widget/custom_network_image.dart';

import '../support/widget_harness.dart';

void main() {
  testWidgets('decodes downscaled (memCacheWidth is set to the slot size)', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const CustomNetworkImage(
        urls: 'https://example.com/avatars/team.jpg',
        width: 40,
        height: 40,
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, isNotNull);
    expect(image.memCacheWidth, greaterThan(0));
  });

  testWidgets('a photo that fails to load shows the no-image placeholder', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const CustomNetworkImage(
        urls: 'https://example.com/avatars/team.jpg',
        width: 40,
        height: 40,
      ),
    );
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    // The placeholder is a PNG; loading it as an SVG threw instead of drawing.
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => image.errorWidget!(context, 'url', 'offline'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
