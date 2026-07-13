// Reproduction for the reported bug: "I send a photo, it shows for a moment
// then vanishes; I only see it again after leaving and re-opening the chat."
//
// Root cause being pinned here: a just-sent image is optimistically inserted
// with `file` = a LOCAL filesystem path. When the send completes the screen
// flips `isLocal` to false (but does NOT replace `file` with the server URL
// yet). SenderMessageWidget then renders the image branch by `isLocal`:
//   isLocal == false  ->  InboxCustomNetworkImage(urls: file)
//                         -> CachedNetworkImage(imageUrl: <local path>)
//                         -> not a URL -> errorWidget ("no image") -> vanish.
//
// Correct behaviour: while `file` is still a local path (not an http URL), the
// bubble must keep rendering the local file, regardless of `isLocal`. Once the
// server URL arrives it renders over the network as usual.
//
// This test pumps SenderMessageWidget with isLocal:false and a local-path file
// (the post-send state) and asserts it does NOT try to load that local path as
// a network image.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  late File tempImage;

  setUp(() {
    // A real file on disk so Image.file has something to point at. The bytes
    // don't need to decode for the widget-type assertion below.
    tempImage = File('${Directory.systemTemp.path}/reacti_test_sent_photo.jpg')
      ..writeAsBytesSync(<int>[0, 1, 2, 3]);
  });

  tearDown(() {
    if (tempImage.existsSync()) tempImage.deleteSync();
  });

  testWidgets(
    'a sent image whose file is still a local path renders the local file, '
    'not a network image (no vanish after send completes)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SenderMessageWidget(
            message: '',
            time: 'now',
            // Post-send state: confirmed (isLocal flipped false) but the file
            // is STILL the local path because the server URL hasn't replaced it.
            isLocal: false,
            file: tempImage.path,
            localPath: tempImage.path,
            mediaType: 'image',
            messageId: 123,
            onLongPress: (_) {},
            onReply: () {},
          ),
        ),
      );
      await tester.pump();

      // The bug: the local path is handed to CachedNetworkImage as a URL, which
      // fails and shows the "no image" error widget. After the fix the bubble
      // renders the local file directly, so no CachedNetworkImage is created
      // for a non-URL path.
      expect(
        find.byType(CachedNetworkImage),
        findsNothing,
        reason:
            'a local file path must not be loaded as a network image; '
            'render it with Image.file until the server URL arrives',
      );
      expect(
        find.byType(Image),
        findsWidgets,
        reason: 'the local image should be shown via Image.file',
      );
    },
  );
}
