// Widget tests for GroupAvatar — the circular group avatar that shows the
// group photo when one is set and a multi-person icon otherwise.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/common_widget/group_avatar.dart';

import '../support/widget_harness.dart';

void main() {
  testWidgets('renders the group photo when a real url is set', (tester) async {
    await pumpInApp(
      tester,
      const GroupAvatar(url: 'https://example.com/groups/team.jpg', size: 40),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.byIcon(Icons.group), findsNothing);
  });

  testWidgets('shows the people icon when the group has no picture', (
    tester,
  ) async {
    await pumpInApp(tester, const GroupAvatar(url: '', size: 40));

    expect(find.byIcon(Icons.group), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('shows the people icon for a null url', (tester) async {
    await pumpInApp(tester, const GroupAvatar(url: null, size: 40));

    expect(find.byIcon(Icons.group), findsOneWidget);
  });

  testWidgets('treats the backend default placeholder as no picture', (
    tester,
  ) async {
    // The group serializer returns asset('default/default_image.jpg') for a
    // group with no photo — a non-empty url that must still show the icon.
    await pumpInApp(
      tester,
      const GroupAvatar(
        url: 'https://staging.reacti.io/default/default_image.jpg',
        size: 40,
      ),
    );

    expect(find.byIcon(Icons.group), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
