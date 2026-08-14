// Unit tests for the signup age-gate helpers (phase A2 of
// docs/PLAN-age-gate-2026-08-04.md).
//
// These guard the client-side courtesy check only — the backend's
// `config('reacti.min_age')` rule is the real gate. What matters here is the
// boundary arithmetic: an off-by-one locks out a legitimate signup on their
// birthday, which is the kind of bug nobody reports, they just leave.
//
// Every case pins `asOf` so the result doesn't depend on the day CI runs.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/helpers_method.dart';

void main() {
  group('ageInYears', () {
    final today = DateTime(2026, 8, 14);

    test('counts a birthday that already passed this year', () {
      expect(ageInYears(DateTime(2000, 1, 1), asOf: today), 26);
    });

    test('does not count a birthday still to come this year', () {
      expect(ageInYears(DateTime(2000, 12, 31), asOf: today), 25);
    });

    test('counts a birthday falling exactly today', () {
      expect(ageInYears(DateTime(2000, 8, 14), asOf: today), 26);
    });

    test('does not count a birthday one day away', () {
      expect(ageInYears(DateTime(2000, 8, 15), asOf: today), 25);
    });

    test('handles a 29 February birthday in a non-leap year', () {
      // Born 2000-02-29, asked on 2026-02-28: the birthday has not arrived.
      expect(
        ageInYears(DateTime(2000, 2, 29), asOf: DateTime(2026, 2, 28)),
        25,
      );
      // ...and on 1 March it has.
      expect(ageInYears(DateTime(2000, 2, 29), asOf: DateTime(2026, 3, 1)), 26);
    });
  });

  group('isOldEnoughToSignUp', () {
    final today = DateTime(2026, 8, 14);

    test('passes on the minimum-age birthday itself', () {
      final dob = DateTime(today.year - kMinSignupAge, today.month, today.day);
      expect(isOldEnoughToSignUp(dob, asOf: today), isTrue);
    });

    test('refuses one day short of the minimum age', () {
      final dob = DateTime(
        today.year - kMinSignupAge,
        today.month,
        today.day + 1,
      );
      expect(isOldEnoughToSignUp(dob, asOf: today), isFalse);
    });

    test('refuses an obvious child', () {
      expect(isOldEnoughToSignUp(DateTime(2020, 1, 1), asOf: today), isFalse);
    });

    test('passes an adult', () {
      expect(isOldEnoughToSignUp(DateTime(1985, 6, 3), asOf: today), isTrue);
    });
  });
}
