// The proof that opening a sealed photo worked, on any lab device.

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_api.dart';
import 'wait.dart';

/// Loads one side's messages (a conversation, or a group's messages).
typedef Messages = Future<List<Map<String, dynamic>>> Function();

/// Waits until the server shows the sealed photo [messageId] was opened by
/// [viewerId]: its reaction reached the sender ([senderSide]) on a device
/// that can film. The iPhone simulator has no camera, so there the photo
/// being marked viewed for the viewer ([viewerSide]) is the proof; the
/// recording itself is covered by the Android emulator and the real iPhone.
Future<void> waitForOpened(
  WidgetTester tester, {
  required int messageId,
  required int viewerId,
  required Messages senderSide,
  required Messages viewerSide,
}) async {
  if ((await availableCameras()).isNotEmpty) {
    await waitFor(
      () async => hasReactionTo(
        await senderSide(),
        messageId: messageId,
        senderId: viewerId,
      ),
      what: 'the reaction to reach the sender',
      tester: tester,
    );
  } else {
    await waitFor(
      () async => (await viewerSide()).any(
        (m) => m['id'] == messageId && _flagOn(m['is_viewed']),
      ),
      what: 'the sealed photo to be marked viewed',
      tester: tester,
    );
  }
}

/// The API sends flags as 1/0 on some endpoints and true/false on others.
bool _flagOn(Object? flag) => flag == true || flag == 1;
