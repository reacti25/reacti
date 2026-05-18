// Unit tests for DeclineRequestRx — the reactive wrapper around the
// decline-friend-request API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton) so
// their logic can be unit-tested with a fake api instead of real HTTP.
// Covers the error path and the success path, plus the singleton default.

import 'package:achiar_expert_app/features/friends/data/rx_decline_request/api.dart';
import 'package:achiar_expert_app/features/friends/data/rx_decline_request/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [DeclineRequestApi] that records the id it was called with and
/// always throws a preset error — exercises [DeclineRequestRx]'s failure path
/// without real HTTP. Uses `implements` so no access to the api's private
/// constructor is needed.
class _ThrowingDeclineRequestApi implements DeclineRequestApi {
  /// The error every [declineRequest] call throws.
  final Object errorToThrow;

  /// How many times [declineRequest] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [declineRequest] call.
  int? lastId;

  _ThrowingDeclineRequestApi(this.errorToThrow);

  @override
  Future<Map> declineRequest({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [DeclineRequestApi] that returns a preset [Map] — exercises
/// [DeclineRequestRx]'s success path without real HTTP.
class _SucceedingDeclineRequestApi implements DeclineRequestApi {
  /// The response every [declineRequest] call resolves with.
  final Map response;

  /// The `id` passed to the most recent [declineRequest] call.
  int? lastId;

  _SucceedingDeclineRequestApi(this.response);

  @override
  Future<Map> declineRequest({required int id}) async {
    lastId = id;
    return response;
  }
}

void main() {
  group('DeclineRequestRx', () {
    test(
      'declineRequest() delegates to the injected api and reports failure on a thrown error',
      () async {
        // A plain Exception (not a DioException) keeps handleErrorWithReturn
        // off its toast branch, which is not test-safe.
        final error = Exception('network down');
        final fake = _ThrowingDeclineRequestApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = DeclineRequestRx(
          api: fake,
          empty: const {},
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.declineRequest(id: 42);

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastId, 42);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'declineRequest() emits the response and returns true on success',
      () async {
        final response = {'success': true, 'message': 'declined'};
        final fetcher = BehaviorSubject<Map>();
        final fake = _SucceedingDeclineRequestApi(response);
        final rx = DeclineRequestRx(
          api: fake,
          empty: const {},
          dataFetcher: fetcher,
        );

        final result = await rx.declineRequest(id: 7);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fake.lastId, 7);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = DeclineRequestRx(
        empty: const {},
        dataFetcher: BehaviorSubject<Map>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(DeclineRequestApi.instance));
    });
  });
}
