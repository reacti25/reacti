// Error-state coverage for FriendsScreen.
//
// A failed friend-list load previously rendered a blank screen (the
// StreamBuilder had no hasError branch). It now shows LoadErrorRetry; tapping
// Retry re-runs the fetch. This pins both.

import 'package:reacti_app/features/friends/data/rx_get_friend_list/rx.dart';
import 'package:reacti_app/features/friends/model/friend_list_response.dart';
import 'package:reacti_app/features/friends/presentation/friends_screen.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../support/widget_harness.dart';

/// Fake friend-list loader: its stream can be seeded with an error, and the
/// retry fetch is counted.
class _ErroringGetFriendListRx extends GetFriendListRx {
  _ErroringGetFriendListRx()
    : super(
        empty: FriendListResponse(),
        dataFetcher: BehaviorSubject<FriendListResponse>(),
      );

  int callCount = 0;

  void seedError() => dataFetcher.addError(Exception('boom'));

  @override
  Future<bool> getFriendList() async {
    callCount++;
    return true;
  }
}

void main() {
  late _ErroringGetFriendListRx fake;
  late GetFriendListRx original;

  setUp(() {
    original = api_access.getFriendListRx;
    fake = _ErroringGetFriendListRx();
    api_access.getFriendListRx = fake;
  });

  tearDown(() {
    api_access.getFriendListRx = original;
  });

  testWidgets('a failed friend-list load shows error + retry, and Retry '
      're-fetches', (tester) async {
    fake.seedError();

    await pumpInApp(tester, const FriendsScreen());
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text("Couldn't load your friends."), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(fake.callCount, 1);
  });
}
