// Test doubles for the DG1 reaction-consent gate.
//
// The real gate (lib/features/chat/data/reaction_consent.dart) shows a dialog
// and talks to permission_handler, neither of which suits a unit/widget test.
// Swap `reactionConsentGate` for one of these in setUp (restore in tearDown).

import 'package:reacti_app/features/chat/data/reaction_consent.dart';
import 'package:flutter/widgets.dart';

/// Always allows — the reaction proceeds. Use for patent happy-path tests.
class AllowingReactionConsentGate extends ReactionConsentGate {
  @override
  Future<bool> ensure(BuildContext context) async => true;
}

/// Always blocks — simulates a user with no consent (or who cancels). Counts
/// how many times it was asked.
class BlockingReactionConsentGate extends ReactionConsentGate {
  int ensureCount = 0;

  @override
  Future<bool> ensure(BuildContext context) async {
    ensureCount++;
    return false;
  }
}
