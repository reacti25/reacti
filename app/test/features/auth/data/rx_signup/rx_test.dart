// Unit tests for SignUpRx — the reactive wrapper around the signup API.
//
// Part of FP1 of the frontend refactor: the rx_* data sources are being
// made injectable (constructor-inject the api, defaulting to the
// singleton) so their logic can be unit-tested with a fake api instead
// of real HTTP. Mirrors the rx_login pattern.
//
// SignUpRx does NOT override handleSuccessWithReturn, so success simply
// emits the decoded `Map` on the stream via the RxResponseInt base
// behaviour — no storage writes. The error handler only does anything
// for a DioException, so a plain Exception cleanly skips the toast.

import 'package:reacti_app/features/auth/data/rx_signup/api.dart';
import 'package:reacti_app/features/auth/data/rx_signup/rx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// A fake [SignUpApi] that records the arguments it was called with and
/// always throws a preset error — exercises [SignUpRx]'s failure path
/// without real HTTP. Uses `implements` so no access to SignUpApi's
/// private constructor is needed.
class _ThrowingSignUpApi implements SignUpApi {
  /// The error every [signup] call throws.
  final Object errorToThrow;

  /// How many times [signup] was invoked.
  int callCount = 0;

  /// The `email` passed to the most recent [signup] call.
  String? lastEmail;

  /// The `dateOfBirth` passed to the most recent [signup] call.
  String? lastDateOfBirth;

  _ThrowingSignUpApi(this.errorToThrow);

  @override
  Future<Map> signup({
    required String fName,
    required String lName,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String password,
    required String confPassword,
  }) async {
    callCount++;
    lastEmail = email;
    lastDateOfBirth = dateOfBirth;
    throw errorToThrow;
  }
}

/// A fake [SignUpApi] that returns a preset response map — exercises
/// [SignUpRx]'s success path without real HTTP.
class _SucceedingSignUpApi implements SignUpApi {
  /// The map every [signup] call resolves with.
  final Map response;

  _SucceedingSignUpApi(this.response);

  @override
  Future<Map> signup({
    required String fName,
    required String lName,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String password,
    required String confPassword,
  }) async => response;
}

void main() {
  group('SignUpRx', () {
    test(
      'signup() delegates to the injected api and reports failure on a thrown error',
      () async {
        final error = Exception('network down');
        final fake = _ThrowingSignUpApi(error);
        final fetcher = BehaviorSubject<Map>();
        final rx = SignUpRx(api: fake, empty: {}, dataFetcher: fetcher);

        // The error the api throws is surfaced on the data stream.
        expectLater(fetcher.stream, emitsError(error));

        final result = await rx.signup(
          fName: 'Alice',
          lName: 'Smith',
          email: 'alice@example.com',
          phone: '12345',
          dateOfBirth: '1990-01-01',
          password: 'secret',
          confPassword: 'secret',
        );

        // The injected fake — not the real singleton — handled the call.
        expect(fake.callCount, 1);
        expect(fake.lastEmail, 'alice@example.com');
        // The birthdate reaches the api layer — the age gate is worthless if
        // the client quietly drops it.
        expect(fake.lastDateOfBirth, '1990-01-01');
        // A thrown api error becomes a `false` result, not an exception.
        expect(result, isFalse);
      },
    );

    test('defaults the api to the shared singleton when none is injected', () {
      final rx = SignUpRx(empty: {}, dataFetcher: BehaviorSubject<Map>());

      // Production call sites omit `api`, so behaviour is unchanged.
      expect(rx.api, same(SignUpApi.instance));
    });

    test('signup() emits the response map on success', () async {
      final response = {'success': true, 'message': 'registered'};
      final fetcher = BehaviorSubject<Map>();
      final rx = SignUpRx(
        api: _SucceedingSignUpApi(response),
        empty: {},
        dataFetcher: fetcher,
      );

      final result = await rx.signup(
        fName: 'Alice',
        lName: 'Smith',
        email: 'a@b.com',
        phone: '12345',
        dateOfBirth: '1990-01-01',
        password: 'pw',
        confPassword: 'pw',
      );

      // The call reports success and the response reaches the stream.
      // SignUpRx does not override handleSuccessWithReturn, so the base
      // class just emits the map — there are no storage side effects.
      expect(result, isTrue);
      expect(fetcher.value, same(response));
    });
  });
}
