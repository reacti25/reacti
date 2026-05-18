// Unit tests for GetProfileRx — the reactive wrapper around the profile
// fetch API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. This file pins GetProfileRx's actual behaviour on both
// the error path and the success path.

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/features/profile/data/rx_get_profile/api.dart';
import 'package:achiar_expert_app/features/profile/data/rx_get_profile/rx.dart';
import 'package:achiar_expert_app/features/profile/model/profile_response.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

import '../../../../support/test_storage.dart';

/// A fake [GetProfileApi] that always throws a preset error — lets us
/// exercise [GetProfileRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the private constructor is needed.
class _ThrowingGetProfileApi implements GetProfileApi {
  /// The error every [getProfile] call throws.
  final Object errorToThrow;

  /// How many times [getProfile] was invoked.
  int callCount = 0;

  _ThrowingGetProfileApi(this.errorToThrow);

  @override
  Future<ProfileResponse> getProfile() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [GetProfileApi] that returns a preset [ProfileResponse] — lets
/// us exercise [GetProfileRx]'s success path without real HTTP.
class _SucceedingGetProfileApi implements GetProfileApi {
  /// The response every [getProfile] call resolves with.
  final ProfileResponse response;

  _SucceedingGetProfileApi(this.response);

  @override
  Future<ProfileResponse> getProfile() async => response;
}

void main() {
  group('GetProfileRx', () {
    test(
      'getProfile() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingGetProfileApi(error);
        final fetcher = BehaviorSubject<ProfileResponse>();
        final rx = GetProfileRx(
          api: fake,
          empty: ProfileResponse(),
          dataFetcher: fetcher,
        );

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.getProfile();

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetProfileRx(
        empty: ProfileResponse(),
        dataFetcher: BehaviorSubject<ProfileResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetProfileApi.instance));
    });

    test(
      'getProfile() emits the response and re-asserts the logged-in flag on success',
      () async {
        await initTestGetStorage();

        final response = ProfileResponse(
          success: true,
          data: Data(id: 7, firstName: 'Alice'),
        );
        final fetcher = BehaviorSubject<ProfileResponse>();
        final rx = GetProfileRx(
          api: _SucceedingGetProfileApi(response),
          empty: ProfileResponse(),
          dataFetcher: fetcher,
        );

        final result = await rx.getProfile();

        // The call reports success and the response reaches the stream.
        expect(result, isTrue);
        expect(fetcher.value, same(response));
        // handleSuccessWithReturn writes kKeyIsLoggedIn = true (current
        // behaviour).
        expect(appData.read(kKeyIsLoggedIn), true);
      },
    );
  });
}
