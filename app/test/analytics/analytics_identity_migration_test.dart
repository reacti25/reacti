// Pins the identity-migration policy that heals devices stuck on a pre-salt
// PostHog distinct id. PostHog refuses to re-identify an already-identified
// user, so a device that ran a pre-salt build keeps emitting under the old
// unsalted person until we reset() it. plan() decides when that reset is
// needed so app + backend stitch into ONE salted person.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_identity_migration.dart';

void main() {
  group('AnalyticsIdentityMigration.plan', () {
    const salted =
        'f5d2022bce74000000000000000000000000000000000000000000000000abcd';

    test('skips when the target (salted id) is empty (anonymous)', () {
      expect(
        AnalyticsIdentityMigration.plan(current: 'anything', target: ''),
        IdentityAction.skip,
      );
    });

    test('skips when the device is already on the salted id', () {
      expect(
        AnalyticsIdentityMigration.plan(current: salted, target: salted),
        IdentityAction.skip,
      );
    });

    test('identifies (no reset) when the current id is unknown', () {
      expect(
        AnalyticsIdentityMigration.plan(current: null, target: salted),
        IdentityAction.identify,
      );
    });

    test('resets then identifies when pinned to a stale unsalted id', () {
      // The exact build-1021 bug: device stuck on the old unsalted person.
      const unsalted =
          '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b';
      expect(
        AnalyticsIdentityMigration.plan(current: unsalted, target: salted),
        IdentityAction.resetThenIdentify,
      );
    });

    test('resets then identifies when still anonymous (PostHog UUID)', () {
      expect(
        AnalyticsIdentityMigration.plan(
          current: '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b',
          target: salted,
        ),
        IdentityAction.resetThenIdentify,
      );
    });
  });
}
