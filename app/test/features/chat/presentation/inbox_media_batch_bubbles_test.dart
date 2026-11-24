// The bug Achia hit on staging 1211 (2026-11-16): three photos picked and sent
// with one caption; once the caption was missing, once only two photos showed,
// until the chat was reopened.
//
// A batch puts all its bubbles on the screen in one tight loop, and each
// bubble's temporary id was the clock in microseconds. Two bubbles created in
// the same microsecond got the same id, and with it the same widget key, so
// one of them was not drawn. Whether it happened depended on how fast the
// phone ran the loop.
//
// This pumps the whole InboxScreen, sends a batch through the same call the
// picker makes, and expects every photo and the caption on the screen while
// the uploads are still running. Everything external is faked.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/rx_get_inbox_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/features/chat/presentation/media_picker_mixin.dart';
import 'package:reacti_app/features/chat/presentation/widget/sender_message_widget.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

import '../../../support/fake_chat_realtime_service.dart';
import '../../../support/test_storage.dart';

const int _myUserId = 1;
const int _peerUserId = 42;
const int _roomId = 99;

/// A 1x1 transparent PNG, so the bubbles have a real picture to load.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// An inbox loader whose thread is empty.
class _EmptyInboxRx extends GetInboxMessageRx {
  _EmptyInboxRx()
    : super(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

  @override
  Future<bool> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    isBlocked = false;
    roomId = _roomId;
    handleSuccessWithReturn(
      InboxResponse(success: true, data: Data(isBlocked: false, chat: [])),
    );
    return true;
  }
}

/// A send that never finishes, so every bubble stays "uploading".
class _NeverFinishingSendRx extends SendMessageRx {
  _NeverFinishingSendRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
    bool oneTime = false,
  }) => Completer<bool>().future;
}

void main() {
  late GetInboxMessageRx originalInbox;
  late SendMessageRx originalSend;
  late ChatRealtimeService Function() originalFactory;
  late Directory photos;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);
    await appData.write(kKeyTourAttachSeen, true);
    FeedbackService.debugPlaySounds = false;
    FeedbackService.setEnabled(false);

    originalInbox = api_access.getInboxMessageRx;
    originalSend = api_access.sendMessageRx;
    originalFactory = chatRealtimeServiceFactory;
    api_access.getInboxMessageRx = _EmptyInboxRx();
    api_access.sendMessageRx = _NeverFinishingSendRx();
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();

    photos = Directory.systemTemp.createTempSync('batch_bubbles');
  });

  tearDown(() {
    api_access.getInboxMessageRx = originalInbox;
    api_access.sendMessageRx = originalSend;
    chatRealtimeServiceFactory = originalFactory;
    FeedbackService.debugPlaySounds = true;
    FeedbackService.setEnabled(true);
    photos.deleteSync(recursive: true);
  });

  testWidgets('a batch of photos shows every photo and its caption at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder:
            (context, _) => MaterialApp(
              navigatorKey: NavigationService.navigatorKey,
              home: const InboxScreen(
                id: _peerUserId,
                roomId: _roomId,
                name: 'Alice',
                image: '',
              ),
            ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Enough photos that some are certain to be created in the same
    // microsecond on any machine; the picker allows this many.
    const count = 10;
    final items = [
      for (var i = 0; i < count; i++)
        ReviewMediaItem(
          XFile(
            (File('${photos.path}/pic_$i.png')..writeAsBytesSync(_png)).path,
          ),
          'image',
        ),
    ];
    final screen =
        tester.state(find.byType(InboxScreen)) as MediaPickerMixin<InboxScreen>;

    unawaited(screen.sendMediaBatch(items, 'trip pics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    final shown = {
      for (final bubble in tester.widgetList<SenderMessageWidget>(
        find.byType(SenderMessageWidget, skipOffstage: false),
      ))
        bubble.file,
    };
    expect(shown, {for (final item in items) item.file.path});
    expect(find.text('trip pics', skipOffstage: false), findsOneWidget);
  });
}
