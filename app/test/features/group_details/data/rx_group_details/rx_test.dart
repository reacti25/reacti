// Unit tests for GroupDetailsRx — the reactive wrapper around the
// group-details API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Covers the error path, the success path and the singleton
// default.

import 'package:reacti_app/features/group_details/data/rx_group_details/api.dart';
import 'package:reacti_app/features/group_details/data/rx_group_details/rx.dart';
import 'package:reacti_app/features/group_details/model/group_details_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GroupDetailsApi] that always throws a preset error — lets us
/// exercise [GroupDetailsRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingGroupDetailsApi implements GroupDetailsApi {
  /// The error every [groupDetails] call throws.
  final Object errorToThrow;

  /// How many times [groupDetails] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [groupDetails] call.
  int? lastId;

  _ThrowingGroupDetailsApi(this.errorToThrow);

  @override
  Future<GroupDetailsResponse> groupDetails({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [GroupDetailsApi] that returns a preset response — lets us
/// exercise [GroupDetailsRx]'s success path without real HTTP.
class _SucceedingGroupDetailsApi implements GroupDetailsApi {
  /// The response every [groupDetails] call resolves with.
  final GroupDetailsResponse response;

  _SucceedingGroupDetailsApi(this.response);

  @override
  Future<GroupDetailsResponse> groupDetails({required int id}) async =>
      response;
}

void main() {
  group('GroupDetailsRx', () {
    test('getGroupDetails() delegates to the injected api and reports failure '
        'on a thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingGroupDetailsApi(error);
      final fetcher = BehaviorSubject<GroupDetailsResponse>();
      final rx = GroupDetailsRx(
        api: fake,
        empty: GroupDetailsResponse(),
        dataFetcher: fetcher,
      );

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.getGroupDetails(id: 42);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastId, 42);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test(
      'getGroupDetails() emits the response and returns true on success',
      () async {
        final response = GroupDetailsResponse(
          success: true,
          data: Data(group: Group(id: 7, name: 'Test Group')),
        );
        final fetcher = BehaviorSubject<GroupDetailsResponse>();
        final rx = GroupDetailsRx(
          api: _SucceedingGroupDetailsApi(response),
          empty: GroupDetailsResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.getGroupDetails(id: 7);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(rx.getGroupDetailsStream.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GroupDetailsRx(
        empty: GroupDetailsResponse(),
        dataFetcher: BehaviorSubject<GroupDetailsResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GroupDetailsApi.instance));
    });
  });
}
