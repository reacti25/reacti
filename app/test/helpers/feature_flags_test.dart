// Pins the feature-flag resolver precedence (--dart-define override > remote
// PostHog flag > safe default) and the fail-safe behaviour when the flag
// service is unavailable. This is the kill-switch that gates the Phase-1 patent
// trigger re-anchor, so its precedence and safe-default must be exact.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/helpers/feature_flags.dart';

/// In-memory [FlagSource] with no I/O — returns whatever the test seeds, or
/// null to simulate "unknown / service down".
class _FakeFlagSource implements FlagSource {
  _FakeFlagSource(this._values);

  final Map<String, bool?> _values;
  bool reloadCalled = false;

  @override
  bool? cached(String key) => _values[key];

  @override
  Future<void> reload(Iterable<String> keys) async {
    reloadCalled = true;
  }
}

void main() {
  group('FeatureFlags.resolve precedence', () {
    test('a true override wins over a false remote and false default', () {
      expect(
        FeatureFlags.resolve(override: 'true', remote: false, fallback: false),
        isTrue,
      );
    });

    test('a false override wins over a true remote', () {
      expect(
        FeatureFlags.resolve(override: 'false', remote: true, fallback: true),
        isFalse,
      );
    });

    test('override accepts "1" as true', () {
      expect(FeatureFlags.resolve(override: '1', fallback: false), isTrue);
    });

    test('an empty or null override falls through to the remote value', () {
      expect(
        FeatureFlags.resolve(override: '', remote: true, fallback: false),
        isTrue,
      );
      expect(
        FeatureFlags.resolve(override: null, remote: false, fallback: true),
        isFalse,
      );
    });

    test('a null remote falls through to the safe default', () {
      expect(FeatureFlags.resolve(remote: null, fallback: true), isTrue);
      expect(FeatureFlags.resolve(remote: null, fallback: false), isFalse);
    });
  });

  group('FeatureFlags.isEnabled over a source', () {
    test(
      'uses the cached remote value when present (no override in tests)',
      () {
        final flags = FeatureFlags.withSource(
          _FakeFlagSource({Flags.reactionTriggerOnPaint: true}),
        );
        expect(flags.isEnabled(Flags.reactionTriggerOnPaint), isTrue);
      },
    );

    test('falls back to the registered default when the source is down', () {
      // Source returns null (service unavailable / never loaded) → default off.
      final flags = FeatureFlags.withSource(
        _FakeFlagSource({Flags.reactionTriggerOnPaint: null}),
      );
      expect(flags.isEnabled(Flags.reactionTriggerOnPaint), isFalse);
    });

    test('an unregistered flag with no remote value is off', () {
      final flags = FeatureFlags.withSource(_FakeFlagSource({}));
      expect(flags.isEnabled('not_a_real_flag'), isFalse);
    });

    test('load() refreshes the source cache', () async {
      final source = _FakeFlagSource({});
      await FeatureFlags.withSource(source).load();
      expect(source.reloadCalled, isTrue);
    });
  });

  group('registry integrity', () {
    test('every registered default has a matching override entry', () {
      // Keeps the three registries in lockstep so a new flag cannot be added to
      // one place and silently ignored by the --dart-define path.
      for (final key in FeatureFlags.defaults.keys) {
        expect(
          FeatureFlags.overrides.containsKey(key),
          isTrue,
          reason: 'Flag "$key" has a default but no overrides entry.',
        );
      }
    });

    test('in-progress flags are registered off by default', () {
      expect(FeatureFlags.defaults[Flags.reactionTriggerOnPaint], isFalse);
    });
  });
}
