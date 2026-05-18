// Unit tests for EditProfileRx — the reactive wrapper around the
// profile-update API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. This file pins EditProfileRx's actual behaviour on both
// the error path and the success path.
//
// Note: EditProfileRx does NOT override handleSuccessWithReturn, so the
// success path uses the base RxResponseInt implementation — it only
// pushes the response onto the stream and writes no storage.
//
// Note on the known bug: EditProfileApi maps the `bio` argument onto the
// backend `dob` form key. That bug lives entirely inside the api's
// FormData construction, which these tests fake out, so it is not
// observable at the Rx layer. The Rx simply forwards `bio` to the api;
// this test asserts that forwarding (the CURRENT behaviour) and does not
// fix the underlying mapping.

import 'package:achiar_expert_app/features/edit_profile/data/rx_edit_profile/api.dart';
import 'package:achiar_expert_app/features/edit_profile/data/rx_edit_profile/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/subjects.dart';

/// A fake [EditProfileApi] that records its arguments and always throws a
/// preset error — lets us exercise [EditProfileRx]'s failure path without
/// real HTTP. Uses `implements` so no access to the private constructor
/// is needed.
class _ThrowingEditProfileApi implements EditProfileApi {
  /// The error every [userEditProfile] call throws.
  final Object errorToThrow;

  /// How many times [userEditProfile] was invoked.
  int callCount = 0;

  /// The `bio` passed to the most recent [userEditProfile] call.
  String? lastBio;

  _ThrowingEditProfileApi(this.errorToThrow);

  @override
  Future<Map> userEditProfile({
    required String fName,
    required String lName,
    XFile? avatar,
    String? phone,
    String? bio,
  }) async {
    callCount++;
    lastBio = bio;
    throw errorToThrow;
  }
}

/// A fake [EditProfileApi] that records its arguments and returns a preset
/// [Map] — lets us exercise [EditProfileRx]'s success path without real
/// HTTP.
class _SucceedingEditProfileApi implements EditProfileApi {
  /// The response every [userEditProfile] call resolves with.
  final Map response;

  /// The `fName` passed to the most recent [userEditProfile] call.
  String? lastFName;

  /// The `lName` passed to the most recent [userEditProfile] call.
  String? lastLName;

  /// The `phone` passed to the most recent [userEditProfile] call.
  String? lastPhone;

  /// The `bio` passed to the most recent [userEditProfile] call.
  String? lastBio;

  _SucceedingEditProfileApi(this.response);

  @override
  Future<Map> userEditProfile({
    required String fName,
    required String lName,
    XFile? avatar,
    String? phone,
    String? bio,
  }) async {
    lastFName = fName;
    lastLName = lName;
    lastPhone = phone;
    lastBio = bio;
    return response;
  }
}

void main() {
  group('EditProfileRx', () {
    test(
      'userEditProfile() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingEditProfileApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = EditProfileRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.userEditProfile(
          fName: 'Alice',
          lName: 'Smith',
          bio: 'hello',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // The Rx forwards `bio` verbatim to the api (the buggy `bio`→`dob`
        // mapping happens inside the api and is not asserted here).
        expect(fake.lastBio, 'hello');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = EditProfileRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(EditProfileApi.instance));
    });

    test(
      'userEditProfile() forwards every argument and emits the response on success',
      () async {
        final response = {'success': true, 'message': 'profile updated'};
        final fake = _SucceedingEditProfileApi(response);
        final fetcher = BehaviorSubject<Map>();
        final rx = EditProfileRx(api: fake, empty: {}, dataFetcher: fetcher);

        final result = await rx.userEditProfile(
          fName: 'Alice',
          lName: 'Smith',
          phone: '12345',
          bio: 'hello',
        );

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // Every argument is forwarded verbatim to the api.
        expect(fake.lastFName, 'Alice');
        expect(fake.lastLName, 'Smith');
        expect(fake.lastPhone, '12345');
        expect(fake.lastBio, 'hello');
        // EditProfileRx does not override handleSuccessWithReturn, so the
        // base RxResponseInt impl runs — no storage write to assert.
      },
    );
  });
}
