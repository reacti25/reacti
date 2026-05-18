// Unit tests for AcceptRequestRx — the reactive wrapper around the
// accept-friend-request API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton) so
// their logic can be unit-tested with a fake api instead of real HTTP.
// Covers the error path and the success path, plus the singleton default.

import 'package:achiar_expert_app/features/friends/data/rx_accept_request/api.dart';
import 'package:achiar_expert_app/features/friends/data/rx_accept_request/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [AcceptRequestApi] that records the id it was called with and
/// always throws a preset error — exercises [AcceptRequestRx]'s failure path
/// without real HTTP. Uses `implements` so no access to the api's private
/// constructor is needed.
class _ThrowingAcceptRequestApi implements AcceptRequestApi {
  /// The error every [acceptRequest] call throws.
  final Object errorToThrow;

  /// How many times [acceptRequest] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [acceptRequest] call.
  int? lastId;

  _ThrowingAcceptRequestApi(this.errorToThrow);

  @override
  Future<Map> acceptRequest({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [AcceptRequestApi] that returns a preset [Map] — exercises
/// [AcceptRequestRx]'s success path without real HTTP.
class _SucceedingAcceptRequestApi implements AcceptRequestApi {
  /// The response every [acceptRequest] call resolves with.
  final Map response;

  /// The `id` passed to the most recent [acceptRequest] call.
  int? lastId;

  _SucceedingAcceptRequestApi(this.response);

  @override
  Future<Map> acceptRequest({required int id}) async {
    lastId = id;
    return response;
  }
}

void main() {
  group('AcceptRequestRx', () {
    test(
      'acceptRequest() delegates to the injected api and reports failure on a thrown error',
      () async {
        // A plain Exception (not a DioException) keeps handleErrorWithReturn
        // off its toast branch, which is not test-safe.
        final error = Exception('network down');
        final fake = _ThrowingAcceptRequestApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = AcceptRequestRx(
          api: fake,
          empty: const {},
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.acceptRequest(id: 42);

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastId, 42);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'acceptRequest() emits the response and returns true on success',
      () async {
        final response = {'success': true, 'message': 'accepted'};
        final fetcher = BehaviorSubject<Map>();
        final fake = _SucceedingAcceptRequestApi(response);
        final rx = AcceptRequestRx(
          api: fake,
          empty: const {},
          dataFetcher: fetcher,
        );

        final result = await rx.acceptRequest(id: 7);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fake.lastId, 7);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = AcceptRequestRx(
        empty: const {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(AcceptRequestApi.instance));
    });
  });
}
