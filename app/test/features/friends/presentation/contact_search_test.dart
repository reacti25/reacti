// Searching the Contacts tab.
//
// The bar above the Friends tab always said "Search user.." and always opened
// the server-side user search — which cannot see the phonebook at all. On the
// Contacts tab that is the wrong search entirely: those contacts are already on
// the device, and the only useful thing to do is narrow them.
//
// What is pinned here is the matching itself, and that the editable field does
// not bring back the double frame the tappable one was rewritten to avoid.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/friends/presentation/find_screen.dart';
import 'package:reacti_app/features/friends/presentation/friends_tab_screen.dart';
import 'package:reacti_app/theme/app_theme.dart';

import '../../../support/widget_harness.dart';

void main() {
  group('contactMatchesQuery', () {
    const phones = ['(050) 123-4567'];

    test('an empty query matches everything', () {
      // The caller passes the query straight through, so this is what keeps an
      // unfiltered list unfiltered.
      expect(contactMatchesQuery('Dana Cohen', phones, ''), isTrue);
    });

    test('matches anywhere in the name, not just the start', () {
      // People search by surname as readily as by first name.
      expect(contactMatchesQuery('Dana Cohen', phones, 'cohen'), isTrue);
      expect(contactMatchesQuery('Dana Cohen', phones, 'ana'), isTrue);
    });

    test('name matching ignores case', () {
      expect(contactMatchesQuery('Dana Cohen', phones, 'dana'), isTrue);
    });

    test('digits match through the formatting on both sides', () {
      // Saved as "(050) 123-4567", remembered as a run of digits. Comparing the
      // strings as typed would find nothing.
      expect(contactMatchesQuery('Dana Cohen', phones, '0501234567'), isTrue);
      expect(contactMatchesQuery('Dana Cohen', phones, '1234567'), isTrue);
      expect(contactMatchesQuery('Dana Cohen', phones, '050-123'), isTrue);
    });

    test('no match is no match', () {
      expect(contactMatchesQuery('Dana Cohen', phones, 'zzz'), isFalse);
      expect(contactMatchesQuery('Dana Cohen', phones, '9999999'), isFalse);
    });

    test('a contact with no number is still searchable by name', () {
      expect(contactMatchesQuery('Dana Cohen', const [], 'dana'), isTrue);
      expect(contactMatchesQuery('Dana Cohen', const [], '050'), isFalse);
    });

    test('a nameless contact does not throw and can match by number', () {
      expect(contactMatchesQuery('', phones, '0501234567'), isTrue);
      expect(contactMatchesQuery('', phones, 'dana'), isFalse);
    });
  });

  group('ContactsSearchField', () {
    Future<void> pumpField(WidgetTester tester, TextEditingController c) =>
        pumpInApp(
          tester,
          ContactsSearchField(controller: c, onChanged: (_) {}),
          theme: AppTheme.dark,
        );

    testWidgets('says contact, not user', (tester) async {
      await pumpField(tester, TextEditingController());
      expect(find.text('Search contact..'), findsOneWidget);
    });

    testWidgets('owns exactly one frame', (tester) async {
      await pumpField(tester, TextEditingController());

      // The theme's inputDecorationTheme supplies an enabledBorder that
      // `border: InputBorder.none` does NOT override — the bug that put two
      // rounded rectangles on top of each other. Every border state is
      // suppressed explicitly; this is what stops that regressing.
      final framed = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => (c.decoration as BoxDecoration?)?.border != null);
      expect(framed.length, 1);
    });

    testWidgets('offers a clear button only once there is text', (
      tester,
    ) async {
      final controller = TextEditingController();
      await pumpField(tester, controller);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'dana');
      await tester.pump();

      // Clearing a filter by selecting the text and deleting it is not a
      // reasonable thing to ask of anyone.
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
