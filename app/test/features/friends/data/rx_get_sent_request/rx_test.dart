// Unit tests for GetSentRequestRx — the reactive wrapper around the
// sent-friend-requests API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton) so
// their logic can be unit-tested with a fake api instead of real HTTP.
// Covers the error path and the success path, plus the singleton default.

import 'package:reacti_app/features/friends/data/rx_get_sent_request/api.dart';
import 'package:reacti_app/features/friends/data/rx_get_sent_request/rx.dart';
import 'package:reacti_app/features/friends/model/get_request_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetSentRequestApi] that always throws a preset error — exercises
/// [GetSentRequestRx]'s failure path without real HTTP. Uses `implements` so
/// no access to the api's private constructor is needed.
class _ThrowingGetSentRequestApi implements GetSentRequestApi {
  /// The error every [getSentRequest] call throws.
  final Object errorToThrow;

  /// How many times [getSentRequest] was invoked.
  int callCount = 0;

  _ThrowingGetSentRequestApi(this.errorToThrow);

  @override
  Future<GetRequestResponse> getSentRequest() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [GetSentRequestApi] that returns a preset [GetRequestResponse] —
/// exercises [GetSentRequestRx]'s success path without real HTTP.
class _SucceedingGetSentRequestApi implements GetSentRequestApi {
  /// The response every [getSentRequest] call resolves with.
  final GetRequestResponse response;

  /// How many times [getSentRequest] was invoked.
  int callCount = 0;

  _SucceedingGetSentRequestApi(this.response);

  @override
  Future<GetRequestResponse> getSentRequest() async {
    callCount++;
    return response;
  }
}

void main() {
  group('GetSentRequestRx', () {
    test(
      'getSentRequestList() delegates to the injected api and reports failure on a thrown error',
      () async {
        // A plain Exception (not a DioException) keeps handleErrorWithReturn
        // off its toast branch, which is not test-safe.
        final error = Exception('network down');
        final fake = _ThrowingGetSentRequestApi(error);
        final fetcher = BehaviorSubject<GetRequestResponse>();
        final rx = GetSentRequestRx(
          api: fake,
          empty: GetRequestResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.getSentRequestList();

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'getSentRequestList() emits the response and returns true on success',
      () async {
        final response = GetRequestResponse(
          success: true,
          message: 'ok',
          code: 200,
          data: Data(
            requests: [Request(id: 5, status: 'pending', isSent: true)],
          ),
        );
        final fetcher = BehaviorSubject<GetRequestResponse>();
        final fake = _SucceedingGetSentRequestApi(response);
        final rx = GetSentRequestRx(
          api: fake,
          empty: GetRequestResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.getSentRequestList();

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fake.callCount, 1);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetSentRequestRx(
        empty: GetRequestResponse(),
        dataFetcher: BehaviorSubject<GetRequestResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetSentRequestApi.instance));
    });
  });
}
