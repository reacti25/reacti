// Tests for the Android gallery's review step (plan Step 7): the system Photo
// Picker returns files, and this screen must hand every one of them, with the
// right kind, any edits and the caption, to the same sealed batch send as iOS.
// Image files here don't exist on disk, so previews fall back to the
// broken-image icon; the logic under test doesn't depend on pixels.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reacti_app/features/chat/presentation/widget/picked_media_review_screen.dart';

void main() {
  group('mediaTypeForPath', () {
    test('reads videos from the extension, case-insensitively', () {
      expect(mediaTypeForPath('/cache/a.mp4'), 'video');
      expect(mediaTypeForPath('/cache/B.MOV'), 'video');
      expect(mediaTypeForPath('/cache/c.3gp'), 'video');
    });

    test('treats everything else as an image', () {
      expect(mediaTypeForPath('/cache/a.jpg'), 'image');
      expect(mediaTypeForPath('/cache/a.heic'), 'image');
      expect(mediaTypeForPath('/cache/no_extension'), 'image');
    });
  });

  group('mediaTypeForFile', () {
    test('trusts the mime type over the extension', () {
      // A video the picker copied without an extension must not become an image.
      expect(
        mediaTypeForFile(XFile('/cache/abc', mimeType: 'video/mp4')),
        'video',
      );
      expect(
        mediaTypeForFile(XFile('/cache/a.mp4', mimeType: 'image/jpeg')),
        'image',
      );
    });

    test('falls back to the extension without a mime type', () {
      expect(mediaTypeForFile(XFile('/cache/a.mov')), 'video');
      expect(mediaTypeForFile(XFile('/cache/a.jpg')), 'image');
    });
  });

  test('only Android uses the system Photo Picker', () {
    expect(usesSystemPhotoPicker(TargetPlatform.android), isTrue);
    expect(usesSystemPhotoPicker(TargetPlatform.iOS), isFalse);
  });

  /// Pushes the review screen over a home route and returns a future that
  /// completes with whatever it pops.
  Future<Future<PickedMedia?>> open(
    WidgetTester tester,
    List<String> paths, {
    Future<String?> Function(BuildContext, String)? editor,
  }) async {
    late Future<PickedMedia?> result;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => MaterialApp(
              home: Builder(
                builder:
                    (context) => TextButton(
                      onPressed: () {
                        result = Navigator.of(context).push<PickedMedia>(
                          MaterialPageRoute(
                            builder:
                                (_) => PickedMediaReviewScreen(
                                  files: [for (final p in paths) XFile(p)],
                                  accent: Colors.green,
                                  onAccent: Colors.white,
                                  editor: editor ?? (_, _) async => null,
                                ),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
              ),
            ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows a thumbnail per picked file', (tester) async {
    await open(tester, ['/p/1.jpg', '/p/2.mp4', '/p/3.png']);
    expect(find.byKey(const Key('review-thumb-0')), findsOneWidget);
    expect(find.byKey(const Key('review-thumb-1')), findsOneWidget);
    expect(find.byKey(const Key('review-thumb-2')), findsOneWidget);
  });

  testWidgets('Send returns every item, typed, in order, with the caption', (
    tester,
  ) async {
    final result = await open(tester, ['/p/1.jpg', '/p/2.mp4']);
    await tester.enterText(find.byKey(const Key('review-caption')), '  trip  ');
    await tester.tap(find.byKey(const Key('review-send')));
    await tester.pumpAndSettle();

    final picked = await result;
    expect(picked, isNotNull);
    expect(
      [for (final i in picked!.items) i.file.path],
      ['/p/1.jpg', '/p/2.mp4'],
    );
    expect([for (final i in picked.items) i.mediaType], ['image', 'video']);
    expect(picked.caption, 'trip');
  });

  testWidgets('an edited image is sent instead of its original', (
    tester,
  ) async {
    final result = await open(tester, [
      '/p/1.jpg',
      '/p/2.jpg',
    ], editor: (_, path) async => '$path.edited.png');
    // Edit the second one only.
    await tester.tap(find.byKey(const Key('review-thumb-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('review-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-send')));
    await tester.pumpAndSettle();

    final picked = await result;
    expect(
      [for (final i in picked!.items) i.file.path],
      ['/p/1.jpg', '/p/2.jpg.edited.png'],
    );
  });

  testWidgets('backing out of the editor keeps the original', (tester) async {
    final result = await open(tester, ['/p/1.jpg']); // editor returns null
    await tester.tap(find.byKey(const Key('review-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-send')));
    await tester.pumpAndSettle();

    expect((await result)!.items.single.file.path, '/p/1.jpg');
  });

  testWidgets('videos offer no Edit action', (tester) async {
    await open(tester, ['/p/1.mp4']);
    expect(find.byKey(const Key('review-edit')), findsNothing);
  });

  testWidgets('backing out sends nothing', (tester) async {
    final result = await open(tester, ['/p/1.jpg']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
