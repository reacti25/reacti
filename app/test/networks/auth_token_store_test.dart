// Unit tests for AuthTokenStore — the secure, in-memory-mirrored holder for
// the auth access token.
//
// Backlog §1 / EP1: the bearer credential moved out of the plaintext
// GetStorage file into flutter_secure_storage. Because the token is read
// synchronously on hot paths, AuthTokenStore mirrors the encrypted value into
// an in-memory cache (`token`) hydrated by `load` and kept current by `save` /
// `clear`. These tests exercise that contract against the mocked secure
// channel from test/support/test_storage.dart.

import 'package:reacti_app/networks/auth_token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_storage.dart';

void main() {
  setUp(() {
    // Fresh, empty in-memory secure backend + reset AuthTokenStore.instance.
    initTestSecureStorage();
  });

  test('token is null before anything is saved', () {
    expect(AuthTokenStore.instance.token, isNull);
  });

  test('save persists the token and exposes it synchronously', () async {
    await AuthTokenStore.instance.save('tok-1');

    expect(AuthTokenStore.instance.token, 'tok-1');
  });

  test('load hydrates the in-memory cache from the secure store', () async {
    await AuthTokenStore.instance.save('tok-2');

    // A fresh store over the same mocked backend starts with an empty cache...
    final fresh = AuthTokenStore();
    expect(fresh.token, isNull);

    // ...until load() reads the persisted value into the cache.
    await fresh.load();
    expect(fresh.token, 'tok-2');
  });

  test('clear erases the token from the cache and the secure store', () async {
    await AuthTokenStore.instance.save('tok-3');

    await AuthTokenStore.instance.clear();

    expect(AuthTokenStore.instance.token, isNull);
    // A reload proves it was removed from the backing store, not just cache.
    final fresh = AuthTokenStore();
    await fresh.load();
    expect(fresh.token, isNull);
  });

  test('save(null) clears the token', () async {
    await AuthTokenStore.instance.save('tok-4');

    await AuthTokenStore.instance.save(null);

    expect(AuthTokenStore.instance.token, isNull);
  });
}
