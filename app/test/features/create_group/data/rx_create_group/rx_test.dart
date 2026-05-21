// Unit tests for CreateGroupRx — the reactive wrapper around the
// create-group API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Covers the error path, the success path and the singleton
// default.

import 'package:reacti_app/features/create_group/data/rx_create_group/api.dart';
import 'package:reacti_app/features/create_group/data/rx_create_group/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/subjects.dart';

/// A fake [CreateGroupApi] that always throws a preset error — lets us
/// exercise [CreateGroupRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingCreateGroupApi implements CreateGroupApi {
  /// The error every [createGroup] call throws.
  final Object errorToThrow;

  /// How many times [createGroup] was invoked.
  int callCount = 0;

  /// The `name` passed to the most recent [createGroup] call.
  String? lastName;

  /// The `memberIds` passed to the most recent [createGroup] call.
  List<int?>? lastMemberIds;

  _ThrowingCreateGroupApi(this.errorToThrow);

  @override
  Future<Map> createGroup({
    required String name,
    String? description,
    required List<int?> memberIds,
    XFile? avatar,
  }) async {
    callCount++;
    lastName = name;
    lastMemberIds = memberIds;
    throw errorToThrow;
  }
}

/// A fake [CreateGroupApi] that returns a preset map — lets us
/// exercise [CreateGroupRx]'s success path without real HTTP.
class _SucceedingCreateGroupApi implements CreateGroupApi {
  /// The response every [createGroup] call resolves with.
  final Map response;

  _SucceedingCreateGroupApi(this.response);

  @override
  Future<Map> createGroup({
    required String name,
    String? description,
    required List<int?> memberIds,
    XFile? avatar,
  }) async => response;
}

void main() {
  group('CreateGroupRx', () {
    test('createGroup() delegates to the injected api and reports failure '
        'on a thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingCreateGroupApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = CreateGroupRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.createGroup(name: 'Squad', memberIds: [1, 2, 3]);

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastName, 'Squad');
      expect(fake.lastMemberIds, [1, 2, 3]);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test(
      'createGroup() emits the response and returns true on success',
      () async {
        final response = {'success': true, 'message': 'created'};
        final fetcher = BehaviorSubject<Map>();
        final rx = CreateGroupRx(
          api: _SucceedingCreateGroupApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.createGroup(name: 'Squad', memberIds: [1, 2]);

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(rx.getFileData.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = CreateGroupRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(CreateGroupApi.instance));
    });
  });
}
