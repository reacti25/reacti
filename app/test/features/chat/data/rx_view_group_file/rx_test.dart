// Unit tests for ViewGroupFileRx — the reactive wrapper around the
// group-chat `mark-viewed` API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP.
//
// PATENT FLOW: `viewGroupFile` is the group-chat counterpart of the
// `mark-viewed` trigger point — once it succeeds the receiver-message
// widget starts the silent reaction recording. These tests verify, with
// extra care, that the rx forwards the file id, reports success/failure
// faithfully and emits the api response onto the stream.

import 'package:reacti_app/features/chat/data/rx_view_group_file/api.dart';
import 'package:reacti_app/features/chat/data/rx_view_group_file/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ViewGroupFileApi] that records the id it was called with and
/// always throws a preset error — exercises [ViewGroupFileRx]'s failure
/// path without real HTTP. Uses `implements` so no access to the api's
/// private constructor is needed.
class _ThrowingViewGroupFileApi implements ViewGroupFileApi {
  /// The error every [viewGroupFile] call throws.
  final Object errorToThrow;

  /// How many times [viewGroupFile] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [viewGroupFile] call.
  int? lastId;

  _ThrowingViewGroupFileApi(this.errorToThrow);

  @override
  Future<Map> viewGroupFile({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [ViewGroupFileApi] that records the id it was called with and
/// returns a preset response — exercises [ViewGroupFileRx]'s success
/// path (the patent mark-viewed trigger) without real HTTP.
class _SucceedingViewGroupFileApi implements ViewGroupFileApi {
  /// The response every [viewGroupFile] call resolves with.
  final Map response;

  /// The `id` passed to the most recent [viewGroupFile] call.
  int? lastId;

  _SucceedingViewGroupFileApi(this.response);

  @override
  Future<Map> viewGroupFile({required int id}) async {
    lastId = id;
    return response;
  }
}

void main() {
  group('ViewGroupFileRx', () {
    test('viewGroupFile() delegates to the injected api and reports failure on '
        'a thrown error', () async {
      // A plain Exception — never a DioException, whose branch calls
      // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
      final error = Exception('mark-viewed failed');
      final fake = _ThrowingViewGroupFileApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = ViewGroupFileRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.viewGroupFile(id: 44);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastId, 44);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('viewGroupFile() forwards the id, emits the response and reports '
        'success', () async {
      // The patent flow waits on this success before recording.
      final response = {'success': true, 'viewed': true};
      final fake = _SucceedingViewGroupFileApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = ViewGroupFileRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.viewGroupFile(id: 21);

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
      // The file id is forwarded to the api unchanged.
      expect(fake.lastId, 21);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ViewGroupFileRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(ViewGroupFileApi.instance));
    });
  });
}
