import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/logic/one_time_media_fetcher.dart';
import 'package:reacti_app/features/chat/logic/screenshot_guard.dart';
import 'package:reacti_app/features/chat/presentation/one_time_media_viewer.dart';

/// Records block/allow so the test can assert protection was scoped to the
/// viewer's lifetime.
class _FakeGuard implements ScreenshotGuard {
  final calls = <String>[];
  @override
  Future<void> block() async => calls.add('block');
  @override
  Future<void> allow() async => calls.add('allow');
}

/// Returns fixed bytes instead of hitting the network.
class _FakeFetcher implements OneTimeMediaFetcher {
  _FakeFetcher(this.bytes);
  final Uint8List bytes;
  int calls = 0;
  @override
  Future<Uint8List> fetch(String url) async {
    calls++;
    return bytes;
  }
}

/// A valid 1x1 transparent PNG so `Image.memory` decodes without a real asset.
final _onePixelPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late ScreenshotGuard originalGuard;
  late OneTimeMediaFetcher originalFetcher;

  setUp(() {
    originalGuard = screenshotGuard;
    originalFetcher = oneTimeMediaFetcher;
  });

  tearDown(() {
    screenshotGuard = originalGuard;
    oneTimeMediaFetcher = originalFetcher;
  });

  testWidgets('blocks capture on open, fetches bytes, releases on close', (
    tester,
  ) async {
    final guard = _FakeGuard();
    final fetcher = _FakeFetcher(_onePixelPng);
    screenshotGuard = guard;
    oneTimeMediaFetcher = fetcher;

    await tester.pumpWidget(
      const MaterialApp(
        home: OneTimeMediaViewer(
          url: 'https://host/api/auth/chat/one-time-media/1',
          mediaType: 'image',
        ),
      ),
    );
    await tester.pump(); // let the fetch future resolve

    // Protection is on and the bytes came from the authed fetcher (not a
    // cached network image).
    expect(guard.calls, contains('block'));
    expect(fetcher.calls, 1);
    expect(find.byType(Image), findsOneWidget);

    // Close the viewer → protection is released.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(guard.calls, ['block', 'allow']);
  });

  testWidgets('shows an unavailable message when the fetch fails', (
    tester,
  ) async {
    screenshotGuard = _FakeGuard();
    oneTimeMediaFetcher = _ThrowingFetcher();

    await tester.pumpWidget(
      const MaterialApp(
        home: OneTimeMediaViewer(
          url: 'https://host/api/auth/chat/one-time-media/1',
          mediaType: 'image',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('This media is no longer available'), findsOneWidget);
  });
}

/// Fails every fetch, standing in for a consumed/destroyed one-time media.
class _ThrowingFetcher implements OneTimeMediaFetcher {
  @override
  Future<Uint8List> fetch(String url) async => throw Exception('gone');
}
