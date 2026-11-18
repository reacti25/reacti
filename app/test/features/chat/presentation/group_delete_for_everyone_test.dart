// "Delete for everyone" in a group chat.
//
// Reported by Achia on staging build 1212 (2026-11-17): a 1:1 chat offers
// "Delete for me" and "Delete for everyone", a group offered only "Delete for
// me". The rule now: your own message can be deleted for everyone, and a
// group admin can delete anyone's.
//
// Pumps the whole GroupInboxScreen over a thread of two text messages (one
// mine, one a peer's), opens the long-press menu and checks which choices the
// delete sheet offers and what the "for everyone" tap sends. Everything
// external is faked.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/chat_realtime_service.dart';
import 'package:reacti_app/features/chat/data/rx_delete_message/api.dart';
import 'package:reacti_app/features/chat/data/rx_delete_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_get_group_inbox/rx.dart';
import 'package:reacti_app/features/chat/model/group_inbox_response.dart';
import 'package:reacti_app/features/chat/presentation/group_inbox_screen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

import '../../../support/fake_chat_realtime_service.dart';
import '../../../support/test_storage.dart';

const int _myUserId = 1;
const int _peerUserId = 42;
const int _groupId = 55;
const int _myMessageId = 10;
const int _peerMessageId = 11;

/// A group loader whose thread holds one message of mine and one of a peer's.
class _TwoMessageGroupRx extends GetGroupInboxRx {
  _TwoMessageGroupRx({required this.isAdmin})
    : super(
        empty: GroupInboxResponse(),
        dataFetcher: BehaviorSubject<GroupInboxResponse>(),
      );

  /// What the server says about the signed-in user's role in the group.
  final bool isAdmin;

  @override
  Future<bool> getGroupInboxMessage({
    required int id,
    int? before,
    int? limit,
  }) async {
    handleSuccessWithReturn(
      GroupInboxResponse(
        success: true,
        data: Data(
          isAdmin: isAdmin,
          pagination: Pagination(hasMore: false),
          messages: [
            Message(
              id: _peerMessageId,
              groupId: _groupId,
              senderId: _peerUserId,
              text: 'theirs',
              createdAt: 'now',
              sender: Sender(id: _peerUserId, firstName: 'Alice'),
            ),
            Message(
              id: _myMessageId,
              groupId: _groupId,
              senderId: _myUserId,
              text: 'mine',
              createdAt: 'now',
              sender: Sender(id: _myUserId, firstName: 'Me'),
            ),
          ],
        ),
      ),
    );
    return true;
  }
}

/// A delete call that records what it was asked to delete and succeeds.
class _RecordingDeleteApi implements DeleteMessageApi {
  /// The (group id, message id) of every group delete, in order.
  final groupDeletes = <(int, int)>[];

  @override
  Future<Map> deleteGroupMessage({
    required int groupId,
    required int messageId,
  }) async {
    groupDeletes.add((groupId, messageId));
    return {'success': true};
  }

  @override
  Future<Map> deleteMessage({required int messageId}) =>
      throw UnimplementedError('a group never deletes a 1:1 message');
}

void main() {
  late GetGroupInboxRx originalInbox;
  late DeleteMessageRx originalDelete;
  late ChatRealtimeService Function() originalFactory;
  late _RecordingDeleteApi deleteApi;

  setUp(() async {
    await initTestGetStorage();
    initTestSecureStorage();
    await appData.write(kKeyUserId, _myUserId);

    originalInbox = api_access.getGroupInboxRx;
    originalDelete = api_access.deleteMessageRx;
    originalFactory = chatRealtimeServiceFactory;

    deleteApi = _RecordingDeleteApi();
    api_access.deleteMessageRx = DeleteMessageRx(
      api: deleteApi,
      empty: {},
      dataFetcher: BehaviorSubject<Map>(),
    );
    chatRealtimeServiceFactory = () => FakeChatRealtimeService();
  });

  tearDown(() {
    api_access.getGroupInboxRx = originalInbox;
    api_access.deleteMessageRx = originalDelete;
    chatRealtimeServiceFactory = originalFactory;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Opens the group as an admin or a plain member and brings up the delete
  /// sheet of the message showing [text].
  Future<void> openDeleteSheet(
    WidgetTester tester,
    String text, {
    required bool isAdmin,
  }) async {
    api_access.getGroupInboxRx = _TwoMessageGroupRx(isAdmin: isAdmin);
    // A phone-shaped screen: on the default 800x600 test surface the menu's
    // last row (Delete) falls off the bottom and cannot be tapped.
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder:
            (context, _) => MaterialApp(
              navigatorKey: NavigationService.navigatorKey,
              home: const GroupInboxScreen(
                roomId: _groupId,
                name: 'Squad',
                groupImage: '',
              ),
            ),
      ),
    );
    await settle(tester);
    await tester.longPress(find.text(text));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Delete for me'), findsOneWidget);
  }

  testWidgets('my own group message can be deleted for everyone', (
    tester,
  ) async {
    await openDeleteSheet(tester, 'mine', isAdmin: false);

    await tester.tap(find.text('Delete for everyone'));
    await settle(tester);

    expect(deleteApi.groupDeletes, [(_groupId, _myMessageId)]);
    expect(find.text('mine'), findsNothing);
    expect(find.text('theirs'), findsOneWidget);
  });

  testWidgets("a member is not offered to delete someone else's message for "
      'everyone', (tester) async {
    await openDeleteSheet(tester, 'theirs', isAdmin: false);

    expect(find.text('Delete for everyone'), findsNothing);
  });

  testWidgets("a group admin can delete someone else's message for everyone", (
    tester,
  ) async {
    await openDeleteSheet(tester, 'theirs', isAdmin: true);

    await tester.tap(find.text('Delete for everyone'));
    await settle(tester);

    expect(deleteApi.groupDeletes, [(_groupId, _peerMessageId)]);
    expect(find.text('theirs'), findsNothing);
  });
}
