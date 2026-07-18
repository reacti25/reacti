import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/screenshot_guard.dart';

/// Records block/allow calls so a viewer test can assert protection was scoped
/// to the sensitive screen.
class _FakeScreenshotGuard implements ScreenshotGuard {
  final calls = <String>[];

  @override
  Future<void> block() async => calls.add('block');

  @override
  Future<void> allow() async => calls.add('allow');
}

void main() {
  test('the default guard is the real, plugin-backed one', () {
    expect(screenshotGuard, isA<RealScreenshotGuard>());
  });

  test('the seam is swappable and records block then allow', () async {
    final original = screenshotGuard;
    final fake = _FakeScreenshotGuard();
    screenshotGuard = fake;
    addTearDown(() => screenshotGuard = original);

    await screenshotGuard.block();
    await screenshotGuard.allow();

    expect(fake.calls, ['block', 'allow']);
  });
}
