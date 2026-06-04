// Unit tests for EditGroupRx — the reactive wrapper around the
// edit-group API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. Covers the error path, the success path and the singleton
// default.

import 'package:reacti_app/features/edit_group/data/rx_edit_group/api.dart';
import 'package:reacti_app/features/edit_group/data/rx_edit_group/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/subjects.dart';

/// A fake [EditGroupApi] that always throws a preset error — lets us
/// exercise [EditGroupRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingEditGroupApi implements EditGroupApi {
  /// The error every [editGroup] call throws.
  final Object errorToThrow;

  /// How many times [editGroup] was invoked.
  int callCount = 0;

  /// The `groupId` passed to the most recent [editGroup] call.
  int? lastGroupId;

  /// The `name` passed to the most recent [editGroup] call.
  String? lastName;

  _ThrowingEditGroupApi(this.errorToThrow);

  @override
  Future<Map> editGroup({
    required int groupId,
    required String name,
    String? description,
    XFile? avatar,
  }) async {
    callCount++;
    lastGroupId = groupId;
    lastName = name;
    throw errorToThrow;
  }
}

/// A fake [EditGroupApi] that returns a preset map — lets us
/// exercise [EditGroupRx]'s success path without real HTTP.
class _SucceedingEditGroupApi implements EditGroupApi {
  /// The response every [editGroup] call resolves with.
  final Map response;

  _SucceedingEditGroupApi(this.response);

  @override
  Future<Map> editGroup({
    required int groupId,
    required String name,
    String? description,
    XFile? avatar,
  }) async => response;
}

void main() {
  group('EditGroupRx', () {
    test('editGroup() delegates to the injected api and reports failure '
        'on a thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingEditGroupApi(error);
      final fetcher = BehaviorSubject<Map>();
      final rx = EditGroupRx(api: fake, empty: {}, dataFetcher: fetcher);

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.editGroup(groupId: 12, name: 'Renamed');

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      expect(fake.lastGroupId, 12);
      expect(fake.lastName, 'Renamed');
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test(
      'editGroup() emits the response and returns true on success',
      () async {
        final response = {'success': true, 'message': 'updated'};
        final fetcher = BehaviorSubject<Map>();
        final rx = EditGroupRx(
          api: _SucceedingEditGroupApi(response),
          empty: {},
          dataFetcher: fetcher,
        );

        final result = await rx.editGroup(groupId: 12, name: 'Renamed');

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        expect(rx.getFileData.value, same(response));
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = EditGroupRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(EditGroupApi.instance));
    });
  });
}
