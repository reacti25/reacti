// Unit tests for SearchUserRx — the reactive wrapper around the
// user-search API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins SearchUserRx's actual behaviour on both the error
// path and the success path.

import 'package:achiar_expert_app/features/search/data/rx_search_user/api.dart';
import 'package:achiar_expert_app/features/search/data/rx_search_user/rx.dart';
import 'package:achiar_expert_app/features/search/model/all_user_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [SearchApi] that records the search term it was called with and
/// always throws a preset error — lets us exercise [SearchUserRx]'s
/// failure path without real HTTP. Uses `implements` so no access to
/// SearchApi's private constructor is needed.
class _ThrowingSearchApi implements SearchApi {
  /// The error every [searchUser] call throws.
  final Object errorToThrow;

  /// How many times [searchUser] was invoked.
  int callCount = 0;

  /// The `search` term passed to the most recent [searchUser] call.
  String? lastSearch;

  _ThrowingSearchApi(this.errorToThrow);

  @override
  Future<AllUserResponse> searchUser({required String search}) async {
    callCount++;
    lastSearch = search;
    throw errorToThrow;
  }
}

/// A fake [SearchApi] that returns a preset [AllUserResponse] — lets us
/// exercise [SearchUserRx]'s success path without real HTTP.
class _SucceedingSearchApi implements SearchApi {
  /// The response every [searchUser] call resolves with.
  final AllUserResponse response;

  _SucceedingSearchApi(this.response);

  @override
  Future<AllUserResponse> searchUser({required String search}) async =>
      response;
}

void main() {
  group('SearchUserRx', () {
    test(
      'searchUser() delegates to the injected api and reports failure on a '
      'thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingSearchApi(error);
        final fetcher = BehaviorSubject<AllUserResponse>();
        final rx = SearchUserRx(
          api: fake,
          empty: AllUserResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.searchUser(search: 'alice');

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastSearch, 'alice');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test(
      'searchUser() emits the response and reports success',
      () async {
        final response = AllUserResponse(
          success: true,
          message: 'OK',
          code: 200,
          data: Data(
            data: [
              Datum(id: 5, fullName: 'Alice', username: 'alice'),
            ],
          ),
        );
        final fetcher = BehaviorSubject<AllUserResponse>();
        final rx = SearchUserRx(
          api: _SucceedingSearchApi(response),
          empty: AllUserResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.searchUser(search: 'alice');

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = SearchUserRx(
        empty: AllUserResponse(),
        dataFetcher: BehaviorSubject<AllUserResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(SearchApi.instance));
    });
  });
}
