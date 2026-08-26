// The Friends app-bar search box drew two overlapping frames.
//
// It was a read-only TextField inside an already-bordered Container. Setting
// `border: InputBorder.none` on an InputDecoration does NOT override the
// theme's `enabledBorder`, so the field painted its own outline inside the
// container's — two rounded rectangles, a couple of pixels apart.
//
// It never took input in the first place (the tap opens the search screen), so
// the field is gone. This pins that it stays gone: reintroduce any text field
// here and the theme brings the second frame straight back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/friends/presentation/friends_tab_screen.dart';
import 'package:reacti_app/theme/app_theme.dart';

import '../../../support/widget_harness.dart';

void main() {
  for (final entry
      in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
    testWidgets('${entry.key}: the search box owns exactly one frame', (
      tester,
    ) async {
      await pumpInApp(tester, const FriendsSearchBox(), theme: entry.value);

      // The theme is the whole point: its inputDecorationTheme is what supplied
      // the second border, so the box has to be pumped under a real one.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);

      // One bordered Container — its own.
      final decorated = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => (c.decoration as BoxDecoration?)?.border != null);
      expect(decorated.length, 1);
    });
  }

  testWidgets('it still reads as a search box', (tester) async {
    await pumpInApp(tester, const FriendsSearchBox(), theme: AppTheme.dark);

    expect(find.text('Search user..'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
