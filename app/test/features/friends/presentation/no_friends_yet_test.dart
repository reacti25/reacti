// The Friends list when the account has none.
//
// Achia, on the walkthrough: a new user has no friends, so sending them to the
// chat list points at nothing. And it is worse than it looks — a 1:1 row only
// appears in the CHAT list once messages have been exchanged, so someone who
// has just added their first friend STILL sees an empty Chat tab.
//
// Which makes this screen the walkthrough's actual next step, and it used to
// say "No friends yet" and nothing else: the one screen whose whole job is to
// be someone's way forward, with no way forward on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/friends/data/rx_get_friend_list/rx.dart';
import 'package:reacti_app/features/friends/model/friend_list_response.dart';
import 'package:reacti_app/features/friends/presentation/friends_screen.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../../support/test_storage.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Pumps [child] in a BOUNDED phone-shaped shell.
///
/// Not the shared `pumpInApp` harness: it wraps its child in a
/// [SingleChildScrollView], and [FriendsScreen] returns a [Scaffold], which
/// cannot size itself against unbounded height.
Future<void> pumpBounded(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1125, 2436);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, _) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

/// Friend-list source whose stream the test seeds directly.
class _FakeGetFriendListRx extends GetFriendListRx {
  _FakeGetFriendListRx()
    : super(
        empty: FriendListResponse(),
        dataFetcher: BehaviorSubject<FriendListResponse>(),
      );

  void seed(List<Datum> friends) =>
      dataFetcher.add(FriendListResponse(data: friends));

  @override
  Future<bool> getFriendList() async => true;
}

void main() {
  late _FakeGetFriendListRx fake;
  late GetFriendListRx original;

  setUp(() async {
    await initTestGetStorage();
    original = api_access.getFriendListRx;
    fake = _FakeGetFriendListRx();
    api_access.getFriendListRx = fake;
  });

  tearDown(() => api_access.getFriendListRx = original);

  testWidgets('an empty list offers two ways to get a friend', (tester) async {
    fake.seed([]);

    await pumpBounded(tester, const FriendsScreen());

    expect(find.text('No friends yet'), findsOneWidget);
    // Contacts first — people you already know are the likeliest first Reacti
    // and need no username anyone has to remember.
    expect(find.text('Find friends from contacts'), findsOneWidget);
    expect(find.text('Search by username'), findsOneWidget);
  });

  testWidgets('the walkthrough marks the way in for an empty account', (
    tester,
  ) async {
    // Achia: with no friends AND no chats, the walkthrough moved her to this
    // tab and then said nothing — which reads as it having broken, not as it
    // having handed over. This is the step that keeps the chain going.
    fake.seed([]);

    await pumpBounded(tester, const FriendsScreen());
    await tester.pump();

    expect(appData.read(kKeyTourAddFriendSeen), isTrue);
  });

  testWidgets('the contacts button calls back to the parent', (tester) async {
    fake.seed([]);
    var jumped = false;

    await pumpBounded(
      tester,
      FriendsScreen(onFindFromContacts: () => jumped = true),
    );

    await tester.tap(find.text('Find friends from contacts'));
    await tester.pump();

    // The Contacts tab belongs to the parent, so the list cannot switch to it
    // alone — a silently dead button here is the same dead end as before.
    expect(jumped, isTrue);
  });
}
