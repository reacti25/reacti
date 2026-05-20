// Unit tests for GetPrivacyRx — the reactive wrapper around the Privacy
// Policy API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are made
// injectable (constructor-inject the api, defaulting to the singleton)
// so their logic can be unit-tested with a fake api instead of real
// HTTP. This file pins GetPrivacyRx's actual behaviour on both the error
// path and the success path.

import 'package:achiar_expert_app/features/privacy/data/rx_get_privacy/api.dart';
import 'package:achiar_expert_app/features/privacy/data/rx_get_privacy/rx.dart';
import 'package:achiar_expert_app/features/privacy/model/privacy_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [GetPrivacyApi] that always throws a preset error — lets us
/// exercise [GetPrivacyRx]'s failure path without real HTTP. Uses
/// `implements` so no access to the api's private constructor is needed.
class _ThrowingGetPrivacyApi implements GetPrivacyApi {
  /// The error every [getPrivacy] call throws.
  final Object errorToThrow;

  /// How many times [getPrivacy] was invoked.
  int callCount = 0;

  _ThrowingGetPrivacyApi(this.errorToThrow);

  @override
  Future<PrivacyResponse> getPrivacy() async {
    callCount++;
    throw errorToThrow;
  }
}

/// A fake [GetPrivacyApi] that returns a preset [PrivacyResponse] — lets
/// us exercise [GetPrivacyRx]'s success path without real HTTP.
class _SucceedingGetPrivacyApi implements GetPrivacyApi {
  /// The response every [getPrivacy] call resolves with.
  final PrivacyResponse response;

  _SucceedingGetPrivacyApi(this.response);

  @override
  Future<PrivacyResponse> getPrivacy() async => response;
}

void main() {
  group('GetPrivacyRx', () {
    test('getPrivacy() delegates to the injected api and reports failure on a '
        'thrown error', () async {
      final error = Exception('network down');
      final fake = _ThrowingGetPrivacyApi(error);
      final fetcher = BehaviorSubject<PrivacyResponse>();
      final rx = GetPrivacyRx(
        api: fake,
        empty: PrivacyResponse(),
        dataFetcher: fetcher,
      );

      // The error the api throws is surfaced on the data stream.
      expectLater(fetcher.stream, emitsError(error));

      final result = await rx.getPrivacy();

      // The injected fake — not the real singleton — handled the call.
      expect(fake.callCount, 1);
      // A thrown api error becomes a `false` result, not an exception.
      expect(result, isFalse);
    });

    test('getPrivacy() emits the response and reports success', () async {
      final response = PrivacyResponse(
        status: true,
        message: 'OK',
        data: Data(
          id: 3,
          pageTitle: 'Privacy Policy',
          pageSlug: 'privacy-policy',
          pageContent: '<p>policy</p>',
          status: 'active',
        ),
      );
      final fetcher = BehaviorSubject<PrivacyResponse>();
      final rx = GetPrivacyRx(
        api: _SucceedingGetPrivacyApi(response),
        empty: PrivacyResponse(),
        dataFetcher: fetcher,
      );

      final result = await rx.getPrivacy();

      // The call reports success and the response reaches the stream.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = GetPrivacyRx(
        empty: PrivacyResponse(),
        dataFetcher: BehaviorSubject<PrivacyResponse>(),
      );

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(GetPrivacyApi.instance));
    });
  });
}
