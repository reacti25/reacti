// SecureScreen: the screenshot block for one-time media is counted (it stays
// on until every holder lets go), tells the native side only when it turns
// on or off, and turns the iPhone's "screenshot" call into an event.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/secure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('reacti/secure_screen');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Object?> sent;

  setUp(() {
    sent = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent.add(call.arguments);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('stays on until every holder lets go, and says so once each way', () {
    final screen = SecureScreen(onPhone: true);

    screen.hold();
    screen.hold();
    screen.release();
    expect(screen.isOn, isTrue, reason: 'one holder is left');

    screen.release();
    screen.release(); // one too many: ignored
    expect(screen.isOn, isFalse);
    expect(sent, [true, false]);
  });

  test("off the phones it counts but never calls the native side", () {
    final screen = SecureScreen(onPhone: false);

    screen.hold();
    expect(screen.isOn, isTrue);
    screen.release();
    expect(sent, isEmpty);
  });

  test("an iPhone's screenshot call becomes an event", () async {
    final screen = SecureScreen(onPhone: true);
    var taken = 0;
    screen.screenshots.listen((_) => taken++);

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('screenshot')),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(taken, 1);
  });
}
