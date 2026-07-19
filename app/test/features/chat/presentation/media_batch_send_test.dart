// Regression test for the WhatsApp-style multi-select send: every selected item
// must go out as its own media message via the normal sendMessage call, so the
// backend seals each one (and each records a reaction when opened — the patent
// flow). This pins "N items -> N media sends, each with a file + the shared
// caption" for both 1:1 and group.

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/chat/data/rx_send_group_message/rx.dart';
import 'package:reacti_app/features/chat/data/rx_send_message/rx.dart';
import 'package:reacti_app/features/chat/presentation/media_picker_mixin.dart';
import 'package:reacti_app/features/chat/presentation/widget/whatsapp_asset_picker.dart';
import 'package:reacti_app/helpers/feedback_service.dart';
import 'package:reacti_app/networks/api_access.dart' as api_access;
import 'package:rxdart/subjects.dart';

/// Records each 1:1 media send so the test can assert one per item.
class _FakeSendMessageRx extends SendMessageRx {
  _FakeSendMessageRx() : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  final files = <XFile?>[];
  final messages = <String?>[];

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    files.add(file);
    messages.add(message);
    return true;
  }
}

/// Records each group media send.
class _FakeSendGroupMessageRx extends SendGroupMessageRx {
  _FakeSendGroupMessageRx()
    : super(empty: {}, dataFetcher: BehaviorSubject<Map>());

  int callCount = 0;

  @override
  Future<bool> sendMessage({
    required int id,
    String? message,
    String? type,
    XFile? file,
    ProgressCallback? onSendProgress,
    int? replyToId,
  }) async {
    callCount++;
    return true;
  }
}

/// Minimal host exposing [MediaPickerMixin.sendMediaBatch] for the test.
class _Host extends StatefulWidget {
  const _Host({required this.group});
  final bool group;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with MediaPickerMixin<_Host> {
  /// Records the optimistic-insert / reconcile calls so the test can assert the
  /// batch shows every item instantly and reconciles each after its upload.
  final inserted = <String>[]; // media types, in insert order
  final reconciled = <bool>[]; // success flags, in reconcile order
  int _nextTempId = 1;

  @override
  int get mediaConversationId => 7;
  @override
  bool get isGroupConversation => widget.group;
  @override
  int insertOptimisticMedia(XFile file, String mediaType, String caption) {
    inserted.add(mediaType);
    return _nextTempId++;
  }

  @override
  void reconcileOptimisticMedia(int tempId, bool success) =>
      reconciled.add(success);
  @override
  Widget build(BuildContext context) => const SizedBox();
}

List<ReviewMediaItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    ReviewMediaItem(XFile('/tmp/pic_$i.jpg'), 'image'),
];

void main() {
  late SendMessageRx originalSend;
  late SendGroupMessageRx originalGroupSend;

  setUp(() {
    originalSend = api_access.sendMessageRx;
    originalGroupSend = api_access.sendGroupMessageRx;
    // Keep the audio/haptic plugin out of the test.
    FeedbackService.debugPlaySounds = false;
    FeedbackService.setEnabled(false);
  });

  tearDown(() {
    api_access.sendMessageRx = originalSend;
    api_access.sendGroupMessageRx = originalGroupSend;
    FeedbackService.debugPlaySounds = true;
    FeedbackService.setEnabled(true);
  });

  testWidgets('1:1 batch sends one media message per item with the caption', (
    tester,
  ) async {
    final fake = _FakeSendMessageRx();
    api_access.sendMessageRx = fake;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(home: _Host(group: false)),
      ),
    );
    final state = tester.state<_HostState>(find.byType(_Host));

    await state.sendMediaBatch(_items(3), 'trip pics');

    expect(fake.files.length, 3);
    expect(fake.files.every((f) => f != null), isTrue); // each carries a file
    // The caption appears once, under the last item — not repeated on all 3.
    expect(fake.messages, ['', '', 'trip pics']);
    // Every item shows optimistically first, then each reconciles as sent.
    expect(state.inserted, ['image', 'image', 'image']);
    expect(state.reconciled, [true, true, true]);
  });

  testWidgets('a single item still carries the caption', (tester) async {
    final fake = _FakeSendMessageRx();
    api_access.sendMessageRx = fake;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(home: _Host(group: false)),
      ),
    );
    final state = tester.state<_HostState>(find.byType(_Host));

    // The only item is also the last, so "caption on the last" must not drop it.
    await state.sendMediaBatch(_items(1), 'just one');

    expect(fake.messages, ['just one']);
  });

  // The pencil in the picker's caption bar writes its result to a temp copy and
  // records it against the asset id; the send path must upload that copy rather
  // than the untouched gallery original.
  test(
    'an edited asset sends the edited copy, an untouched one the original',
    () {
      const picked = WhatsAppPickResult([], 'cap', {
        'a1': '/tmp/edited_a1.jpg',
      });

      expect(picked.pathFor('a1', '/gallery/a1.jpg'), '/tmp/edited_a1.jpg');
      expect(picked.pathFor('a2', '/gallery/a2.jpg'), '/gallery/a2.jpg');
    },
  );

  testWidgets('group batch sends one media message per item', (tester) async {
    final fake = _FakeSendGroupMessageRx();
    api_access.sendGroupMessageRx = fake;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(home: _Host(group: true)),
      ),
    );
    final state = tester.state<_HostState>(find.byType(_Host));

    await state.sendMediaBatch(_items(4), '');

    expect(fake.callCount, 4);
    expect(state.inserted, ['image', 'image', 'image', 'image']);
    expect(state.reconciled, [true, true, true, true]);
  });
}
