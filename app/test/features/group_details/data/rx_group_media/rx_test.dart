// Unit tests for GetGroupMediaRx — the reactive wrapper around the
// group-media API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Covers the error path, the success path and the singleton
// default.

import 'package:reacti_app/features/group_details/data/rx_group_media/api.dart';
import 'package:reacti_app/features/group_details/data/rx_group_media/rx.dart';
import 'package:reacti_app/features/group_details/model/group_media_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GroupMediaApi] that always throws a preset error — lets us
/// exercise [GetGroupMediaRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingGroupMediaApi implements GroupMediaApi {
  /// The error every [groupMediaList] call throws.
  final Object errorToThrow;

  /// How many times [groupMediaList] was invoked.
  int callCount = 0;

  /// The `id` passed to the most recent [groupMediaList] call.
  int? lastId;

  _ThrowingGroupMediaApi(this.errorToThrow);

  @override
  Future<GroupMediaResponse> groupMediaList({required int id}) async {
    callCount++;
    lastId = id;
    throw errorToThrow;
  }
}

/// A fake [GroupMediaApi] that returns a preset response — lets us
/// exercise [GetGroupMediaRx]'s success path without real HTTP.
class _SucceedingGroupMediaApi implements GroupMediaApi {
  /// The response every [groupMediaList] call resolves with.
  final GroupMediaResponse response;

  _SucceedingGroupMediaApi(this.response);

  @override
  Future<GroupMediaResponse> groupMediaList({required int id}) async =>
      response;
}

void main() {
  group('GetGroupMediaRx', () {
    test('groupMediaList() delegates to the injected api and reports failure '
        'on a thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingGroupMediaApi(error);
      final fetcher = BehaviorSubject<GroupMediaResponse>();
      final rx = GetGroupMediaRx(
        api: fake,
        empty: GroupMediaResponse(),
        dataFetcher: fetcher,
      );

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.groupMediaList(id: 99);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastId, 99);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test(
      'groupMediaList() emits the response and returns true on success',
      () async {
        final response = GroupMediaResponse(
          success: true,
          data: Data(media: [Media(id: 1, fileType: 'image')]),
        );
        final fetcher = BehaviorSubject<GroupMediaResponse>();
        final rx = GetGroupMediaRx(
          api: _SucceedingGroupMediaApi(response),
          empty: GroupMediaResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.groupMediaList(id: 1);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(rx.getGroupMediaStream.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetGroupMediaRx(
        empty: GroupMediaResponse(),
        dataFetcher: BehaviorSubject<GroupMediaResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GroupMediaApi.instance));
    });
  });
}
