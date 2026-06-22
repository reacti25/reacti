// Widget test for the scroll-to-load-older lazy pagination on InboxScreen.
//
// Mirrors the already-shipped group lazy-load behaviour on the 1:1 side: on
// open the screen loads the newest page (6 messages, newest-first, with
// `pagination.has_more = true`); scrolling toward the top (the reversed list's
// maxScrollExtent) triggers fetchOlder, which appends an older page.
//
// Everything external is faked so no network/Pusher is needed:
//   - getInboxMessageRx   -> emits a canned newest page on open and serves an
//                            older page from fetchOlder (no real HTTP)
//   - ChatRealtimeService -> a fake injected via chatRealtimeServiceFactory,
//                            so connect() opens no websocket.
//
// The first page renders, and after scrolling to the top the older page's
// messages are appended and rendered.

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/rx_get_inbox_message/rx.dart';
import 'package:reacti_app/features/chat/model/inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/inbox_screen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../support/fake_chat_realtime_service.dart';
import '../../../support/test_storage.dart';

const int _myUserId = 1;
const int _peerUserId = 42;
const int _roomId = 99;

/// Builds a plain (non-sealed) text [Chat] authored by the peer.
Chat _peerText(int id, String text) => Chat(
  id: id,
  senderId: _peerUserId,
  receiverId: _myUserId,
  roomId: _roomId,
  text: text,
  mediaType: 'text',
  humanizeDate: 'now',
  sender: Receiver(id: _peerUserId, firstName: 'Alice'),
  receiver: Receiver(id: _myUserId, firstName: 'Me'),
);

/// Fake inbox loader: serves a canned cursor-mode newest page on open and a
/// canned older page from [fetchOlder], recording the cursor it was asked for.
class _FakeLazyInboxRx extends GetInboxMessageRx {
  _FakeLazyInboxRx(this._firstPage, this._olderPage)
    : super(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

  /// The newest page emitted onto the stream on open (newest-first, has_more).
  final InboxResponse _firstPage;

  /// The older page returned by [fetchOlder] (newest-first).
  final InboxResponse _olderPage;

  /// How many times [fetchOlder] was invoked.
  int fetchOlderCount = 0;

  /// The `before` cursor of the most recent [fetchOlder] call.
  int? lastBefore;

  @override
  Future<bool> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    isBlocked = _firstPage.data?.isBlocked;
    roomId = _firstPage.data?.room?.id;
    handleSuccessWithReturn(_firstPage);
    return true;
  }

  @override
  Future<InboxResponse?> fetchOlder({
    required int id,
    required int before,
    required int limit,
  }) async {
    fetchOlderCount++;
    lastBefore = before;
    return _olderPage;
  }
}

/// Wraps [screen] in a ScreenUtil + MaterialApp tree.
Widget _wrap(Widget screen) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder:
      (context, _) => MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: screen,
      ),
);

void main() {
  late _FakeLazyInboxRx fakeGetInbox;
  late GetInboxMessageRx originalGetInbox;
  late ChatRealtimeService Function() originalFactory;

  // Newest page: 6 messages, newest-first (id 16 down to 11), has_more=true.
  InboxResponse firstPage() => InboxResponse(
    success: true,
    data: Data(
      isBlocked: false,
      chat: [for (var id = 16; id >= 11; id--) _peerText(id, 'msg $id')],
      pagination: Pagination(hasMore: true),
    ),
  );

  // Older page: 6 messages, newest-first (id 10 down to 5), no more older.
  InboxResponse olderPage() => InboxResponse(
    success: true,
    data: Data(
      isBlocked: false,
      chat: [for (var id = 10; id >= 5; id--) _peerText(id, 'msg $id')],
      pagination: Pagination(hasMore: false),
    ),
  );

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);

    originalGetInbox = api_access.getInboxMessageRx;
    originalFactory = chatRealtimeServiceFactory;

    fakeGetInbox = _FakeLazyInboxRx(firstPage(), olderPage());
    api_access.getInboxMessageRx = fakeGetInbox;
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();
  });

  tearDown(() {
    api_access.getInboxMessageRx = originalGetInbox;
    chatRealtimeServiceFactory = originalFactory;
  });

  testWidgets('renders the newest page on open and loads older on scroll up', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const InboxScreen(
          id: _peerUserId,
          roomId: _roomId,
          name: 'Alice',
          image: '',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The newest page rendered (newest message is visible at the bottom of the
    // reversed list).
    expect(find.text('msg 16'), findsOneWidget);

    // Scroll the reversed list toward the top (older end = maxScrollExtent),
    // which triggers the older-page fetch.
    final listFinder = find.byType(Scrollable).first;
    await tester.drag(listFinder, const Offset(0, 600));
    await tester.pump();
    await tester.pump();
    // Let any viewport-fill follow-up settle.
    await tester.pump(const Duration(milliseconds: 50));

    // fetchOlder fired with the oldest loaded id (11) as the cursor.
    expect(fakeGetInbox.fetchOlderCount, greaterThanOrEqualTo(1));
    expect(fakeGetInbox.lastBefore, 11);

    // Scroll to the very top of the (now-extended) reversed list so the oldest
    // appended message is laid out, then assert it rendered.
    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(find.text('msg 5'), findsOneWidget);
  });
}
