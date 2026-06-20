// Widget tests for AvatarCircle — the shared circular avatar that shows a
// network photo when a url is present and a stable, per-name initials circle
// otherwise.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/common_widget/avatar_circle.dart';

import '../support/widget_harness.dart';

void main() {
  testWidgets('renders a network image for a real photo url', (tester) async {
    await pumpInApp(
      tester,
      const AvatarCircle(
        url: 'https://example.com/avatars/jane.jpg',
        firstName: 'Jane',
        lastName: 'Doe',
        size: 40,
      ),
    );

    // The network path is taken; the initials circle is only the placeholder
    // that shows while the photo loads / if it fails.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('no-photo sender in a 1:1 chat (empty avatar) shows initials', (
    tester,
  ) async {
    // ChatMessageResource returns the raw (empty) avatar for a photoless user.
    await pumpInApp(
      tester,
      const AvatarCircle(url: '', firstName: 'Jane', lastName: 'Doe', size: 40),
    );

    expect(find.text('JD'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets(
    'no-photo sender in a group chat (default placeholder url) shows initials',
    (tester) async {
      // GroupMessageFormatResource returns asset('default/default_image.jpg')
      // for a photoless user — a non-empty url that must still fall back.
      await pumpInApp(
        tester,
        const AvatarCircle(
          url: 'https://staging.reacti.io/default/default_image.jpg',
          firstName: 'Jane',
          lastName: 'Doe',
          size: 40,
        ),
      );

      expect(find.text('JD'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    },
  );

  testWidgets('treats every backend default-avatar marker as no photo', (
    tester,
  ) async {
    const defaultUrls = [
      'https://reacti.io/default/default_image.jpg',
      'https://cdn.reacti.io/assets/DEFAULT/default_image.jpg', // host casing
      'https://reacti.io/img/placeholder-image.png',
    ];

    for (final url in defaultUrls) {
      await pumpInApp(
        tester,
        AvatarCircle(url: url, firstName: 'Jane', lastName: 'Doe', size: 40),
      );

      expect(find.text('JD'), findsOneWidget, reason: 'should fall back: $url');
      expect(
        find.byType(CachedNetworkImage),
        findsNothing,
        reason: 'should not load default image: $url',
      );
    }
  });

  testWidgets('uses a single initial when only one name is present', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      const AvatarCircle(url: null, firstName: 'Jane', size: 40),
    );

    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('falls back to "?" when both names are empty', (tester) async {
    await pumpInApp(
      tester,
      const AvatarCircle(url: '', firstName: '', lastName: '', size: 40),
    );

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('same name yields the same background colour', (tester) async {
    Color colorFor(AvatarCircle a) {
      final container = a.build(_FakeContext()) as Container;
      return (container.decoration as BoxDecoration).color!;
    }

    final a = colorFor(
      const AvatarCircle(firstName: 'Jane', lastName: 'Doe', size: 40),
    );
    final b = colorFor(
      const AvatarCircle(firstName: 'Jane', lastName: 'Doe', size: 40),
    );
    final c = colorFor(
      const AvatarCircle(firstName: 'John', lastName: 'Roe', size: 40),
    );

    expect(a, b); // deterministic per name
    expect(a, isNot(c)); // different names differ (for this palette)
  });
}

/// Minimal [BuildContext] stand-in: the empty-url branch of [AvatarCircle.build]
/// never touches the context, so a bare fake is enough to read its colour.
class _FakeContext extends Fake implements BuildContext {}
