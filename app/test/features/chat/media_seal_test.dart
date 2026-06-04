import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/presentation/media_seal.dart';

/// Regression lock for the patent media-seal decision.
///
/// The receiver's media must render SEALED whenever `is_blurred` is truthy,
/// regardless of whether the API delivered it as the conversation REST endpoint's
/// JSON bool (`true`) or the realtime path's int (`1`). A prior `== 1`-only check
/// failed the bool case (Dart `true == 1` is false), so history-loaded images
/// arrived unsealed for the receiver and the tap-to-view that triggers
/// `mark-viewed` + the silent reaction recording never fired.
void main() {
  group('isMediaSealed', () {
    test('seals when is_blurred is the REST JSON bool true', () {
      expect(isMediaSealed(true), isTrue);
    });

    test('seals when is_blurred is the realtime int 1', () {
      expect(isMediaSealed(1), isTrue);
    });

    test('does not seal for false, 0, or null', () {
      expect(isMediaSealed(false), isFalse);
      expect(isMediaSealed(0), isFalse);
      expect(isMediaSealed(null), isFalse);
    });
  });
}
