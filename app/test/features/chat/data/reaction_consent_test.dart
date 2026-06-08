// Unit tests for ReactionConsentGate's persistence (DG1).
//
// The dialog + OS-permission path is exercised on-device / via the swappable
// gate in widget tests; here we pin the consent flag persisted in GetStorage.

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/reaction_consent.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_storage.dart';

void main() {
  setUp(() async {
    await initTestGetStorage();
    await appData.erase();
  });

  test('hasConsent is false until consent is granted', () {
    expect(ReactionConsentGate().hasConsent, isFalse);
  });

  test('grantConsent persists the consent flag', () async {
    final gate = ReactionConsentGate();

    await gate.grantConsent();

    expect(gate.hasConsent, isTrue);
    expect(appData.read(kKeyReactionConsent), true);
  });
}
