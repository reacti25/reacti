import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/call_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('reacti/call_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reports the native answer', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isInCall');
      return true;
    });
    expect(await CallStatus(onPhone: true).isInCall(), isTrue);
  });

  test('off a phone it never asks the native side', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    expect(await CallStatus(onPhone: false).isInCall(), isFalse);
  });

  test(
    'fails open when there is no native side (tests, older builds)',
    () async {
      expect(await CallStatus(onPhone: true).isInCall(), isFalse);
    },
  );

  test('fails open when the native side throws', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'boom'),
    );
    expect(await CallStatus(onPhone: true).isInCall(), isFalse);
  });
}
