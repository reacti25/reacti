import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely-persisted auth access token with a synchronous in-memory mirror.
///
/// The access token is the app's bearer credential, so it is stored in the
/// platform secure store ([FlutterSecureStorage] — Keychain on iOS,
/// `EncryptedSharedPreferences` / Keystore on Android) instead of the
/// plaintext GetStorage JSON file the rest of the app uses for non-secret
/// preferences.
///
/// [FlutterSecureStorage] is async-only, but the token is read *synchronously*
/// on several hot paths (Dio `Authorization` header assembly, chat-screen
/// init for Pusher auth). To keep those call sites synchronous — and avoid
/// async-refactoring widget `initState`s — the encrypted value is mirrored
/// into an in-memory cache that [token] returns without I/O. [load] hydrates
/// the cache from the secure store once at startup; [save] and [clear] keep
/// the secure store and the cache in sync.
///
/// Only the access token lives here. The (non-credential) user id and FCM
/// token remain in GetStorage.
class AuthTokenStore {
  /// Creates a store over [storage], defaulting to the platform secure store.
  ///
  /// [storage] is injectable so tests can supply a fake backend (or the
  /// production secure store is exercised through a mocked platform channel).
  AuthTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Process-wide instance used by the app.
  ///
  /// Mutable so a test can replace it with a store over a fake backend.
  static AuthTokenStore instance = AuthTokenStore();

  /// Key under which the access token is stored in the secure store.
  static const String storageKey = 'auth_access_token';

  /// The secure-storage backend the token is persisted to.
  final FlutterSecureStorage _storage;

  /// In-memory mirror of the persisted token, kept current by [load] / [save]
  /// / [clear] so [token] can be read synchronously.
  String? _cached;

  /// The current access token, or `null` when logged out.
  ///
  /// Synchronous: returns the in-memory mirror, which is valid after [load]
  /// (called once at startup) and kept current by [save] / [clear].
  String? get token => _cached;

  /// Hydrates the in-memory cache from the secure store.
  ///
  /// Call once at startup, after the platform channels are ready, so the
  /// synchronous [token] getter returns the persisted value.
  Future<void> load() async {
    _cached = await _storage.read(key: storageKey);
  }

  /// Persists [value] to the secure store and updates the in-memory cache.
  ///
  /// A `null` or empty [value] erases the token (equivalent to [clear]).
  Future<void> save(String? value) async {
    if (value == null || value.isEmpty) {
      await clear();
      return;
    }
    _cached = value;
    await _storage.write(key: storageKey, value: value);
  }

  /// Erases the token from the secure store and the in-memory cache.
  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: storageKey);
  }
}
