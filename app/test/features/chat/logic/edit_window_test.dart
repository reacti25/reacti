// Unit tests for the edit-window rule that decides whether the chat action
// menu offers "Edit" — it must vanish once the 10-minute window has passed.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/edit_window.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16, 12, 0, 0);

  test('editable just after sending', () {
    expect(
      canEditMessageAt(now.subtract(const Duration(seconds: 1)), now),
      isTrue,
    );
  });

  test('editable at 9m59s', () {
    expect(
      canEditMessageAt(
        now.subtract(const Duration(minutes: 9, seconds: 59)),
        now,
      ),
      isTrue,
    );
  });

  test('not editable exactly at 10 minutes', () {
    expect(
      canEditMessageAt(now.subtract(const Duration(minutes: 10)), now),
      isFalse,
    );
  });

  test('not editable well past the window', () {
    expect(
      canEditMessageAt(now.subtract(const Duration(hours: 2)), now),
      isFalse,
    );
  });

  test('not editable when the send time is unknown (null)', () {
    expect(canEditMessageAt(null, now), isFalse);
  });

  test('slight clock skew (future send time) is treated as editable', () {
    expect(canEditMessageAt(now.add(const Duration(seconds: 5)), now), isTrue);
  });
}
