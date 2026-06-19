/// How to reconcile the PostHog SDK's on-device identity with our salted id.
///
/// PostHog assigns every event to a *person* using the SDK's internal,
/// on-device `distinct_id` (set via `identify`) — NOT the `distinct_id`
/// property we attach to events. Critically, the native SDK **refuses to
/// re-identify an already-identified user**: once a device has been
/// `identify`-ed, a later `identify` with a different id is silently ignored
/// until `reset()` is called.
///
/// This bit us: builds before the salting fix called `identify(<unsalted
/// hash>)`, which the device persisted. After the fix, `identify(<salted
/// hash>)` is a no-op on those devices, so app events keep emitting under the
/// stale unsalted person (it resurrects after every server-side delete) and
/// never stitch to the backend's salted person.
///
/// [AnalyticsIdentityMigration.plan] decides the SDK calls needed to make the
/// salted id win, given the device's current distinct id.
enum IdentityAction {
  /// Already on the salted id (or nothing to identify) — do nothing.
  skip,

  /// Identify directly (current id unknown — best effort, no reset).
  identify,

  /// `reset()` to anonymous first, then `identify` — the device is pinned to a
  /// stale/other id the SDK would otherwise refuse to overwrite.
  resetThenIdentify,
}

/// Pure policy for migrating a device onto the salted analytics identity.
class AnalyticsIdentityMigration {
  AnalyticsIdentityMigration._();

  /// Plans how to make [target] (the salted distinct id) the device's PostHog
  /// identity, given the SDK's [current] distinct id (`null` when it could not
  /// be read).
  ///
  /// - empty [target] → [IdentityAction.skip] (anonymous; never identify).
  /// - [current] already equals [target] → [IdentityAction.skip].
  /// - [current] is `null` (unknown) → [IdentityAction.identify] (best effort).
  /// - otherwise → [IdentityAction.resetThenIdentify]: [current] is a stale
  ///   (pre-salt) or anonymous id the SDK won't overwrite via `identify`, so we
  ///   reset to anonymous first. Resetting a merely-anonymous device is
  ///   harmless — the subsequent identify re-stitches it to [target].
  static IdentityAction plan({
    required String? current,
    required String target,
  }) {
    if (target.isEmpty) return IdentityAction.skip;
    if (current == target) return IdentityAction.skip;
    if (current == null) return IdentityAction.identify;
    return IdentityAction.resetThenIdentify;
  }
}
