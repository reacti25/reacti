// Error-state coverage for InboxScreen.
//
// Previously a failed conversation load rendered a blank screen (the
// StreamBuilder's `else` returned SizedBox.shrink() with no hasError branch).
// Now it shows LoadErrorRetry; tapping Retry re-runs the fetch. This pins both.

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

/// Fake inbox loader: errors on the first load, then succeeds with an empty
/// conversation on the retry — so the test can drive failure → recover.
class _FlakyGetInboxMessageRx extends GetInboxMessageRx {
  _FlakyGetInboxMessageRx()
    : super(
        empty: InboxResponse(),
        dataFetcher: BehaviorSubject<InboxResponse>(),
      );

  int callCount = 0;

  @override
  Future<bool> getInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    callCount++;
    if (callCount == 1) {
      dataFetcher.sink.addError(Exception('boom'));
      return false;
    }
    isBlocked = false;
    handleSuccessWithReturn(
      InboxResponse(success: true, data: Data(isBlocked: false, chat: [])),
    );
    return true;
  }
}

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
  late _FlakyGetInboxMessageRx fakeGetInbox;
  late GetInboxMessageRx originalGetInbox;
  late ChatRealtimeService Function() originalFactory;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, 1);

    originalGetInbox = api_access.getInboxMessageRx;
    originalFactory = chatRealtimeServiceFactory;

    fakeGetInbox = _FlakyGetInboxMessageRx();
    api_access.getInboxMessageRx = fakeGetInbox;
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();
  });

  tearDown(() {
    api_access.getInboxMessageRx = originalGetInbox;
    chatRealtimeServiceFactory = originalFactory;
  });

  Future<void> drainAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a failed conversation load shows an error + retry, not a blank '
      'screen, and Retry re-fetches', (tester) async {
    await tester.pumpWidget(
      _wrap(const InboxScreen(id: 42, roomId: 99, name: 'Alice', image: '')),
    );
    await drainAsync(tester);

    // The error state is shown after the load fails.
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text("Couldn't load this conversation."), findsOneWidget);
    expect(fakeGetInbox.callCount, 1);

    // Tapping Retry re-runs the fetch, which now succeeds and clears the error.
    await tester.tap(find.text('Retry'));
    await drainAsync(tester);

    expect(fakeGetInbox.callCount, 2);
    expect(find.text('Retry'), findsNothing);
  });
}
