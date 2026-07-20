// Unit tests for DeleteForMeRx — the reactive wrapper around the
// "delete for me" API (1:1 and group).

import 'package:reacti_app/features/chat/data/rx_delete_for_me/api.dart';
import 'package:reacti_app/features/chat/data/rx_delete_for_me/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake api recording which method was called with which id.
class _FakeDeleteForMeApi implements DeleteForMeApi {
  final bool shouldThrow;
  int? lastChatId;
  int? lastGroupId;

  _FakeDeleteForMeApi({this.shouldThrow = false});

  @override
  Future<Map> deleteForMe({required int messageId}) async {
    lastChatId = messageId;
    if (shouldThrow) throw Exception('boom');
    return {'success': true};
  }

  @override
  Future<Map> deleteGroupForMe({required int messageId}) async {
    lastGroupId = messageId;
    if (shouldThrow) throw Exception('boom');
    return {'success': true};
  }
}

void main() {
  group('DeleteForMeRx', () {
    test('deleteForMe forwards the id and reports success', () async {
      final fake = _FakeDeleteForMeApi();
      final rx = DeleteForMeRx(
        api: fake,
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      final ok = await rx.deleteForMe(messageId: 42);

      expect(ok, isTrue);
      expect(fake.lastChatId, 42);
    });

    test('deleteGroupForMe forwards the id and reports success', () async {
      final fake = _FakeDeleteForMeApi();
      final rx = DeleteForMeRx(
        api: fake,
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      final ok = await rx.deleteGroupForMe(messageId: 7);

      expect(ok, isTrue);
      expect(fake.lastGroupId, 7);
    });

    test('reports failure on a thrown api error', () async {
      final fake = _FakeDeleteForMeApi(shouldThrow: true);
      final rx = DeleteForMeRx(
        api: fake,
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      expect(await rx.deleteForMe(messageId: 1), isFalse);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = DeleteForMeRx(empty: {}, dataFetcher: BehaviorSubject<Map>());
      expect(rx.api, same(DeleteForMeApi.instance));
    });
  });
}
