// Guards the invite Universal Link against re-opening itself.
//
// The bug this file exists for: tapping an invite link with Reacti installed
// made the app open, close and reopen until the phone was unusable. Two things
// fed it — iOS re-delivering the same link on every foreground, and
// `app_links` replaying the cold-start link on the stream as well as returning
// it from getInitialLink — so the same code arrived over and over.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/invite/data/invite_deep_links.dart';

void main() {
  setUp(InviteDeepLinks.resetForTest);

  group('codeFrom', () {
    test('pulls the code out of a real invite link', () {
      expect(
        InviteDeepLinks.codeFrom(Uri.parse('https://reacti.io/i/AbC123')),
        'AbC123',
      );
    });

    test('still matches once the page has stamped itself web-handled', () {
      // The landing page appends ?web=1 so the AASA exclusion can stop a
      // browser reload bouncing back into the app. A user who taps that
      // stamped link from elsewhere should still land on the connect screen,
      // so the query must not defeat the match.
      expect(
        InviteDeepLinks.codeFrom(Uri.parse('https://reacti.io/i/AbC123?web=1')),
        'AbC123',
      );
    });

    test('staging and production hosts both work', () {
      expect(
        InviteDeepLinks.codeFrom(
          Uri.parse('https://staging.reacti.io/i/xyz789'),
        ),
        'xyz789',
      );
    });

    test('a link that carries no invite code is ignored', () {
      expect(InviteDeepLinks.codeFrom(Uri.parse('https://reacti.io/')), isNull);
      expect(
        InviteDeepLinks.codeFrom(Uri.parse('https://reacti.io/about')),
        isNull,
      );
      // No code at all after /i/ — must not match an empty string.
      expect(
        InviteDeepLinks.codeFrom(Uri.parse('https://reacti.io/i/')),
        isNull,
      );
    });
  });
}
