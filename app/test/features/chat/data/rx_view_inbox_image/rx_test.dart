// Unit tests for ViewInboxImageRx — the reactive wrapper around the
// one-to-one `mark-viewed` API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP.
//
// PATENT FLOW: `viewInboxImage` is the `mark-viewed` trigger point —
// once it succeeds the receiver-message widget starts the silent
// reaction recording. These tests verify, with extra care, that the rx
// forwards the message id, reports success/failure faithfully and emits
// the api response onto the stream (which the widget waits on before
// recording).

import 'package:achiar_expert_app/features/chat/data/rx_view_inbox_image/api.dart';
import 'package:achiar_expert_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [ViewInboxImageApi] that records the id it was called with and
/// always throws a preset error — exercises [ViewInboxImageRx]'s failure
/// path without real HTTP. Uses `implements` so no access to the api's
/// private constructor is needed.
class _ThrowingViewInboxImageApi implements ViewInboxImageApi {
  /// The error every [viewInboxImage] call throws.
  final Object errorToThrow;

  /// How many times [viewInboxImage] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [viewInboxImage] call.
  int? lastId;

  _ThrowingViewInboxImageApi(this.errorToThrow);

  @override
  Future<Map> viewInboxImage({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [ViewInboxImageApi] that records the id it was called with and
/// returns a preset response — exercises [ViewInboxImageRx]'s success
/// path (the patent mark-viewed trigger) without real HTTP.
class _SucceedingViewInboxImageApi implements ViewInboxImageApi {
  /// The response every [viewInboxImage] call resolves with.
  final Map response;

  /// The `id` passed to the most recent [viewInboxImage] call.
  int? lastId;

  _SucceedingViewInboxImageApi(this.response);

  @override
  Future<Map> viewInboxImage({required int id}) async {
    lastId = id;
    return response;
  }
}

void main() {
  group('ViewInboxImageRx', () {
    test(
      'viewInboxImage() delegates to the injected api and reports failure on '
      'a thrown error',
      () async {
        // A plain Exception — never a DioException, whose branch calls
        // ToastUtil (GetX + flutter_screenutil), which is not test-safe.
        final error = Exception('mark-viewed failed');
        final fake = _ThrowingViewInboxImageApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = ViewInboxImageRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.viewInboxImage(id: 33);

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastId, 33);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('viewInboxImage() forwards the id, emits the response and reports '
        'success', () async {
      // The patent flow waits on this success before recording.
      final response = {'success': true, 'viewed': true};
      final fake = _SucceedingViewInboxImageApi(response);
      final fetcher = BehaviorSubject<Map>();
      final rx = ViewInboxImageRx(api: fake, empty: {}, dataFetcher: fetcher);

      final result = await rx.viewInboxImage(id: 17);

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
      // The message id is forwarded to the api unchanged.
      expect(fake.lastId, 17);
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = ViewInboxImageRx(
        empty: {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(ViewInboxImageApi.instance));
    });
  });
}
