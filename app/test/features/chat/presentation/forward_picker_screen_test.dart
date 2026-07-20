// Widget tests for ForwardPickerScreen — rendering the conversation list and
// multi-select behaviour. The send path calls ToastUtil (GetX snackbar), which
// isn't test-safe, so it's covered by the ForwardMessageRx + backend tests.

import 'package:reacti_app/features/chat/data/rx_get_all_chat/api.dart';
import 'package:reacti_app/features/chat/data/rx_get_all_chat/rx.dart';
import 'package:reacti_app/features/chat/model/chat_list_response.dart';
import 'package:reacti_app/features/chat/presentation/forward_picker_screen.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake chat-list api returning a canned response — no HTTP.
class _FakeGetAllChatApi implements GetAllChatApi {
  final ChatListResponse response;

  _FakeGetAllChatApi(this.response);

  @override
  Future<ChatListResponse> getAllChat() async => response;
}

void main() {
  late GetAllChatRx original;

  setUp(() {
    original = api_access.getAllChatRx;
    final response = ChatListResponse(
      data: Data(
        chats: [
          Chat(type: 'single', id: 11, name: 'Alice'),
          Chat(type: 'group', id: 22, name: 'Team', avatar: ''),
        ],
      ),
    );
    api_access.getAllChatRx = GetAllChatRx(
      api: _FakeGetAllChatApi(response),
      empty: ChatListResponse(),
      dataFetcher: BehaviorSubject<ChatListResponse>.seeded(response),
    );
  });

  tearDown(() {
    api_access.getAllChatRx = original;
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder:
            (_, _) => const MaterialApp(
              home: ForwardPickerScreen(
                sourceMessageId: 5,
                sourceType: 'single',
              ),
            ),
      ),
    );
    await tester.pump();
  }

  group('ForwardPickerScreen', () {
    testWidgets('lists the user\'s conversations', (tester) async {
      await pumpPicker(tester);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget); // the group subtitle
    });

    testWidgets('selecting recipients reveals the send button with a count', (
      tester,
    ) async {
      await pumpPicker(tester);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Alice'));
      await tester.pump();
      expect(find.text('Send (1)'), findsOneWidget);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Team'));
      await tester.pump();
      expect(find.text('Send (2)'), findsOneWidget);

      // Deselecting removes it from the count.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Alice'));
      await tester.pump();
      expect(find.text('Send (1)'), findsOneWidget);
    });
  });
}
