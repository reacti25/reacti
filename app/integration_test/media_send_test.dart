// Sending photos and videos on a device, against the throwaway test server:
// the gallery batch with the editor and a shared caption, the in-app camera
// (photo and video, Android: the iPhone simulator has no camera), and playing
// a video someone sent. Each send is checked on the receiver's side of the
// server. Driven by the testing lab (.github/workflows/testing-lab.yml).

import 'dart:io';

import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:reacti_app/main.dart' as app;
import 'package:reacti_app/networks/endpoints.dart' as endpoints;

import 'support/app_session.dart';
import 'support/e2e_api.dart';
import 'support/wait.dart';

/// A photo and a video from the app's own assets, real files the server and
/// the compressor accept. The lab adds the same two to the iPhone's library.
const photoAsset = 'assets/images/on_board_image1.png';
const videoAsset = 'assets/demo/friend_moment.mp4';

/// Android's gallery is the system Photo Picker, which Dart cannot tap: this
/// stands in for it and "picks" [files]. Everything after the pick (review,
/// editor, caption, send) is the app's own code.
class _PickerStandIn extends ImagePickerPlatform {
  _PickerStandIn(this.files);

  final List<XFile> files;

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async => files;
}

/// Copies the asset [asset] to a temp file, as a picked file would be.
Future<XFile> assetFile(String asset) async {
  final bytes = await rootBundle.load(asset);
  final file = File('${Directory.systemTemp.path}/${asset.split('/').last}');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  return XFile(file.path);
}

/// The composer's attach button.
final attachButton = find.byWidgetPredicate(
  (w) =>
      w is SvgPicture &&
      (w.bytesLoader as SvgAssetLoader).assetName.contains('attachment_icon'),
);

/// Opens the attach sheet and picks [option] ('Gallery' or 'Camera').
Future<void> attach(WidgetTester tester, String option) async {
  await pumpUntilFound(tester, attachButton);
  await tester.tap(attachButton);
  await pumpUntilFound(tester, find.text(option));
  // The sheet slides up: a tap mid-animation misses the row.
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(option));
}

/// Confirms the image editor as it opened.
Future<void> confirmEditor(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byTooltip('Done'));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.byTooltip('Done'));
}

/// Android: the review screen after the system picker, with the editor.
Future<void> sendBatchOnAndroid(WidgetTester tester, String caption) async {
  await pumpUntilFound(tester, find.byKey(const Key('review-send')));
  await tester.tap(find.byKey(const Key('review-edit')));
  await confirmEditor(tester);
  await pumpUntilFound(tester, find.byKey(const Key('review-caption')));
  await tester.enterText(find.byKey(const Key('review-caption')), caption);
  await tester.tap(find.byKey(const Key('review-send')));
}

/// iPhone: the app's own grid picker over the simulator's library.
Future<void> sendBatchOnIphone(WidgetTester tester, String caption) async {
  // Each grid tile toggles on a tap of its backdrop.
  final tiles = find.byWidgetPredicate(
    (w) =>
        w is GestureDetector &&
        w.behavior == HitTestBehavior.opaque &&
        w.child is AnimatedContainer,
  );
  // at(1) would throw while the grid is still loading: count instead.
  await waitFor(
    () async => tiles.evaluate().length >= 2,
    what: 'the photo and the video in the picker',
    tester: tester,
  );
  await tester.tap(tiles.at(0));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(tiles.at(1));
  // The filmstrip's photo opens the editor (its pencil badge).
  final pencil = find.byIcon(Icons.edit);
  await pumpUntilFound(tester, pencil);
  await tester.tap(pencil.first);
  await confirmEditor(tester);
  final captionField = find.widgetWithText(TextField, 'Add a caption…');
  await pumpUntilFound(tester, captionField);
  await tester.enterText(captionField, caption);
  await tester.tap(find.byIcon(Icons.send_rounded));
}

/// The camera's round shutter button.
final shutter = find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.onTap != null &&
      w.child is Container &&
      ((w.child as Container).decoration as BoxDecoration?)?.shape ==
          BoxShape.circle,
);

/// Android: a photo and a video from the in-app camera, each sent.
Future<void> sendFromCamera(WidgetTester tester) async {
  final send = find.byKey(const Key('composer_send_button'));
  final staged = find.byKey(const Key('staged_attachment_preview'));

  await attach(tester, 'Camera');
  await pumpUntilFound(tester, shutter);
  await tester.pump(const Duration(seconds: 2)); // the lens warms up
  await tester.tap(shutter);
  await confirmEditor(tester);
  await pumpUntilFound(tester, staged);
  await tester.tap(send);
  await tester.pump(const Duration(seconds: 2));

  await attach(tester, 'Camera');
  await pumpUntilFound(tester, find.text('Video'));
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(find.text('Video'));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(shutter); // starts recording
  await tester.pump(const Duration(seconds: 3));
  await tester.tap(shutter); // stops it
  await pumpUntilFound(tester, find.text('Use'));
  await tester.tap(find.text('Use'));
  await pumpUntilFound(tester, staged);
  await tester.tap(send);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('send photos and videos, and play a received video', (
    tester,
  ) async {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final bravo = await E2eUser.login(endpoints.url, userBEmail);
    final alpha = await E2eUser.login(endpoints.url, userAEmail);
    Future<List<Map<String, dynamic>>> fromAlpha(String type) async =>
        (await bravo.conversation(alpha.id))
            .where((m) => m['sender_id'] == alpha.id && m['media_type'] == type)
            .toList();

    await bravo.sendText(alpha.id, 'send me something');
    await startLoggedIn(tester, app.main, userAEmail);
    await pumpUntilFound(tester, find.text('Smoke Bravo'));
    await tester.tap(find.text('Smoke Bravo'));

    // A photo and a video from the gallery, one caption on the batch.
    const caption = 'lab batch caption';
    if (android) {
      ImagePickerPlatform.instance = _PickerStandIn([
        await assetFile(photoAsset),
        await assetFile(videoAsset),
      ]);
    }
    await attach(tester, 'Gallery');
    await (android ? sendBatchOnAndroid : sendBatchOnIphone)(tester, caption);
    await waitFor(
      () async =>
          (await fromAlpha('image')).isNotEmpty &&
          (await fromAlpha('video')).any((m) => m['text'] == caption),
      what: 'the photo and the captioned video to reach smoke-b',
      tester: tester,
      timeout: const Duration(minutes: 3),
    );
    // And the sender sees each of them once: a caption-less echo once took
    // the captioned bubble, two bubbles shared an id, and one went missing.
    await waitFor(
      () async =>
          tester
              .widgetList<SenderMessageWidget>(find.byType(SenderMessageWidget))
              .where((w) => w.mediaType == 'image' || w.mediaType == 'video')
              .length ==
          (await fromAlpha('image')).length + (await fromAlpha('video')).length,
      what: "alpha's own screen to show every photo and video it sent",
      tester: tester,
    );

    if (android) {
      await sendFromCamera(tester);
      await waitFor(
        () async =>
            (await fromAlpha('image')).length >= 2 &&
            (await fromAlpha('video')).length >= 2,
        what: 'the camera photo and video to reach smoke-b',
        tester: tester,
        timeout: const Duration(minutes: 3),
      );
    }

    // A video smoke-b sends: open it and it plays.
    final video = await rootBundle.load(videoAsset);
    await bravo.sendFile(alpha.id, video.buffer.asUint8List(), 'clip.mp4');
    final sealed = find.text('Click to view the media');
    await pumpUntilFound(tester, sealed);
    await tester.tap(sealed.last);
    await waitFor(
      () async => tester
          .widgetList<FlickVideoPlayer>(find.byType(FlickVideoPlayer))
          .any(
            (p) =>
                p
                    .flickManager
                    .flickVideoManager
                    ?.videoPlayerValue
                    ?.isInitialized ??
                false,
          ),
      what: 'the received video to load and play',
      tester: tester,
      timeout: const Duration(minutes: 2),
    );
    await letPopupsFinish(tester);
  });
}
