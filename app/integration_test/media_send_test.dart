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

/// The file names of the [count] newest photos and videos alpha sent.
Future<List<String>> newestFiles(
  Future<List<Map<String, dynamic>>> Function(String type) fromAlpha,
  int count,
) async {
  final sent = [...await fromAlpha('image'), ...await fromAlpha('video')]
    ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
  return [for (final m in sent.take(count)) '${m['file']}'.split('/').last];
}

/// Waits until the sender's own screen has a bubble for each of [files]:
/// two bubbles once shared one id after a mismatched echo, and one of them
/// was never drawn.
Future<void> senderShowsEach(WidgetTester tester, List<String> files) =>
    waitFor(
      () async {
        final shown = {
          for (final w in tester.widgetList<SenderMessageWidget>(
            find.byType(SenderMessageWidget),
          ))
            '${w.file}'.split('/').last,
        };
        return files.every(shown.contains);
      },
      what: "alpha's own screen to show each of $files",
      tester: tester,
    );

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

    // A gallery batch with one caption, which goes on its last item. Android
    // sends two photos: the case Achia hit on staging 1204, where the first
    // photo's caption-less echo took the captioned bubble of the second.
    const caption = 'lab batch caption';
    if (android) {
      ImagePickerPlatform.instance = _PickerStandIn([
        await assetFile(photoAsset),
        await assetFile(photoAsset),
      ]);
    }
    await attach(tester, 'Gallery');
    await (android ? sendBatchOnAndroid : sendBatchOnIphone)(tester, caption);
    await waitFor(
      () async =>
          android
              ? (await fromAlpha('image')).length >= 2 &&
                  (await fromAlpha('image')).any((m) => m['text'] == caption)
              // The simulator's library order varies, so the caption may
              // ride on either the photo or the video, whichever came last.
              : (await fromAlpha('image')).isNotEmpty &&
                  (await fromAlpha('video')).isNotEmpty &&
                  [
                    ...await fromAlpha('image'),
                    ...await fromAlpha('video'),
                  ].any((m) => m['text'] == caption),
      what: 'the batch, captioned last item included, to reach smoke-b',
      tester: tester,
      timeout: const Duration(minutes: 3),
    );
    await senderShowsEach(tester, await newestFiles(fromAlpha, 2));

    if (android) {
      await sendFromCamera(tester);
      await waitFor(
        () async =>
            (await fromAlpha('image')).length >= 3 &&
            (await fromAlpha('video')).isNotEmpty,
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
