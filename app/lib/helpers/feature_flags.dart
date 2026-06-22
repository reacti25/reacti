import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../analytics/analytics_config.dart';

/// Registered feature-flag keys — the wire names used both in PostHog and in
/// the `--dart-define=flag.<key>=true|false` build override.
///
/// This is the **single place new flags are declared**. Add the key here, its
/// safe default in [FeatureFlags.defaults], and its compile-time override in
/// [FeatureFlags.overrides] (the override needs a const literal name).
class Flags {
  Flags._();

  /// Phase-1 re-anchor of the silent-recording trigger to the first painted
  /// frame. **Off by default** until proven on the overlap dashboard.
  static const String reactionTriggerOnPaint = 'reaction_trigger_on_paint';
}

/// A remote source of feature-flag values, cached for synchronous reads.
///
/// PostHog's SDK resolves flags asynchronously, but the patent trigger needs a
/// flag decision synchronously at tap time — so values are pre-fetched into a
/// cache ([reload]) and read synchronously ([cached]).
abstract interface class FlagSource {
  /// Cached value for [key], or null when unknown/unavailable so the resolver
  /// falls through to the safe default.
  bool? cached(String key);

  /// Refreshes the cache for [keys]. Fail-safe — never throws.
  Future<void> reload(Iterable<String> keys);
}

/// Resolves a feature flag with fixed precedence:
///
/// 1. **compile-time** `--dart-define=flag.<key>=true|false` override
///    (deterministic per build — wins when set),
/// 2. **remote** PostHog flag (cached at startup),
/// 3. **safe default** from [defaults] (flag absent everywhere → default;
///    in-progress work is registered off).
///
/// Reads are synchronous; [load] pre-fetches the remote values once at startup.
/// With no analytics keys (plain/prod build, all tests) the remote source is
/// inert and every flag resolves to its default — current behaviour unchanged.
class FeatureFlags {
  FeatureFlags._(this._source);

  /// Process-wide instance backed by PostHog.
  static final FeatureFlags instance = FeatureFlags._(PostHogFlagSource());

  /// Test seam: build an instance over a fake [FlagSource].
  @visibleForTesting
  FeatureFlags.withSource(this._source);

  final FlagSource _source;

  /// Whether [key] is enabled, applying the precedence above. Synchronous and
  /// safe to call on the load-bearing patent path.
  bool isEnabled(String key) => resolve(
    override: overrides[key],
    remote: _source.cached(key),
    fallback: defaults[key] ?? false,
  );

  /// Pre-fetches remote values for every registered flag. Fire-and-forget at
  /// startup; until it completes (or if it fails) flags resolve to their
  /// override/default, so the safe path is never blocked.
  Future<void> load() => _source.reload(defaults.keys);

  /// Pure precedence resolver (override > remote > fallback). A non-empty
  /// [override] is read as a boolean string (`true`/`1` → true, else false);
  /// a null/empty override falls through to [remote], then [fallback].
  static bool resolve({
    String? override,
    bool? remote,
    required bool fallback,
  }) {
    if (override != null && override.isNotEmpty) {
      return override == 'true' || override == '1';
    }
    if (remote != null) return remote;
    return fallback;
  }

  /// Safe defaults — the registry of known flags. Everything in-progress is off.
  static const Map<String, bool> defaults = {
    Flags.reactionTriggerOnPaint: false,
  };

  /// Compile-time overrides, read as const because [String.fromEnvironment]
  /// requires a literal name. An empty string means "no override for this flag"
  /// (the common case — overrides are only set on a specific staging build).
  static const Map<String, String> overrides = {
    Flags.reactionTriggerOnPaint: String.fromEnvironment(
      'flag.reaction_trigger_on_paint',
    ),
  };
}

/// [FlagSource] backed by PostHog's cached feature flags.
class PostHogFlagSource implements FlagSource {
  final Map<String, bool> _cache = {};

  @override
  bool? cached(String key) => _cache[key];

  @override
  Future<void> reload(Iterable<String> keys) async {
    // No analytics keys → no SDK; leave the cache empty so flags use defaults.
    if (!AnalyticsConfig.analyticsEnabled) return;
    try {
      await Posthog().reloadFeatureFlags();
      for (final key in keys) {
        _cache[key] = await Posthog().isFeatureEnabled(key);
      }
    } catch (_) {
      // Flag service unavailable → keep whatever is cached; resolver falls back.
    }
  }
}
