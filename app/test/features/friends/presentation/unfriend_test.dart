// Unfriending, and leaving a group, both reported by Achia as "doesn't do
// anything".
//
// Leaving a group genuinely did nothing — `case 'leave'` wrote a log line and
// nothing else; the endpoint had no client at all. Unfriending was wired, but
// its menu button sat inside a 20-logical-pixel box, well under the 48px an
// IconButton lays out for, so taps near the edges of the visible dots fell
// through to the tile underneath (which opens the chat).
//
// Both are destructive and neither asked first, which is its own bug: a
// mis-tap in a menu removed a friendship silently, and the only way back is a
// fresh request the other person has to accept.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/friends/data/rx_get_friend_list/rx.dart';
import 'package:reacti_app/features/friends/data/rx_unfriend_user/rx.dart';
import 'package:reacti_app/features/friends/model/friend_list_response.dart';
import 'package:reacti_app/features/friends/presentation/friends_screen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

import '../../../support/test_storage.dart';

/// Pumps a fixed number of frames.
///
/// Never `pumpAndSettle` in this file: each friend row carries a network avatar
/// whose placeholder spinner animates forever, so settling never returns.
Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FakeGetFriendListRx extends GetFriendListRx {
  _FakeGetFriendListRx()
    : super(
        empty: FriendListResponse(),
        dataFetcher: BehaviorSubject<FriendListResponse>(),
      );

  int refreshes = 0;

  void seed(List<Datum> friends) =>
      dataFetcher.add(FriendListResponse(data: friends));

  @override
  Future<bool> getFriendList() async {
    refreshes++;
    return true;
  }
}

class _FakeUnfriendUserRx extends UnfriendUserRx {
  _FakeUnfriendUserRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int calls = 0;
  int? lastId;
  bool succeeds = true;

  @override
  Future<bool> unfriendUser({required int id}) async {
    calls++;
    lastId = id;
    return succeeds;
  }
}

/// Pumps the friend list on a phone-shaped, bounded surface.
Future<void> pumpFriends(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1125, 2436);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, _) => const MaterialApp(home: FriendsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  late _FakeGetFriendListRx list;
  late _FakeUnfriendUserRx unfriend;
  late GetFriendListRx originalList;
  late UnfriendUserRx originalUnfriend;

  setUp(() async {
    await initTestGetStorage();
    // Established user: the walkthrough tip on the first row draws a
    // full-screen overlay that would eat every tap in this file.
    await appData.write(kKeyTourFirstChatSeen, true);

    originalList = api_access.getFriendListRx;
    originalUnfriend = api_access.unfriendUserRx;
    list = _FakeGetFriendListRx();
    unfriend = _FakeUnfriendUserRx();
    api_access.getFriendListRx = list;
    api_access.unfriendUserRx = unfriend;
    list.seed([Datum(id: 42, name: 'Dana Cohen')]);
  });

  tearDown(() {
    api_access.getFriendListRx = originalList;
    api_access.unfriendUserRx = originalUnfriend;
  });

  testWidgets('the menu button is big enough to hit', (tester) async {
    await pumpFriends(tester);

    // 48x48 is the minimum an IconButton lays out for, and the minimum Apple
    // and Material both call tappable. Boxed to 20 wide, the overflow was
    // clipped and edge taps fell through to the tile.
    final size = tester.getSize(find.byType(PopupMenuButton<String>));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('unfriending asks first, and Cancel does nothing', (
    tester,
  ) async {
    await pumpFriends(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await drain(tester);
    await tester.tap(find.text('Unfriend'));
    await drain(tester);

    expect(find.text('Unfriend Dana Cohen?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await drain(tester);

    // A mis-tap in a menu must not silently end a friendship.
    expect(unfriend.calls, 0);
  });

  testWidgets('confirming unfriends that person and refreshes', (tester) async {
    await pumpFriends(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await drain(tester);
    await tester.tap(find.text('Unfriend'));
    await drain(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Unfriend'));
    await drain(tester);

    expect(unfriend.calls, 1);
    expect(unfriend.lastId, 42, reason: 'the friend\'s USER id, not a row id');
    // Refreshed, so the row goes rather than lingering until the next visit.
    expect(list.refreshes, greaterThan(0));
  });

  testWidgets('a failed unfriend says so instead of failing silently', (
    tester,
  ) async {
    unfriend.succeeds = false;
    await pumpFriends(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await drain(tester);
    await tester.tap(find.text('Unfriend'));
    await drain(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Unfriend'));
    await drain(tester);

    expect(find.textContaining("Couldn't unfriend"), findsOneWidget);
  });
}
