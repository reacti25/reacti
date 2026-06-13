<?php

namespace Tests\BackwardsCompat;

use Tests\Contract\Support\ContractMatcher;
use Tests\TestCase;

/**
 * Base class for backwards-compatibility tests (Plan A1).
 *
 * Where the Contract suite (tests/Contract) pins the *candidate* backend's
 * current response shape, this suite pins the response shape the **currently
 * live App Store app (v1.0.9)** requires — frozen at the moment that build
 * shipped. It is the direct guard against the 2026-05-23 incident: a backend
 * change to a field type the old app can't parse (e.g. `is_viewed` int -> bool)
 * empties the live app's chat screens. Running the live app's expected shapes
 * against the candidate backend catches that before it can reach production.
 *
 * The expectation schemas under live-app-v1.0.9/ were derived field-by-field
 * from the Dart models at the pinned tag `app-live-v1.0.9` (commit d064643) —
 * each field's type token mirrors how that model's `fromJson` parses it:
 *
 *   - a value parsed into `int?`     -> "integer|null"   (STRICT; a bool crashes)
 *   - a value parsed into `String?`  -> "string|null"
 *   - a value parsed into `bool?`    -> "boolean|null"
 *   - a value parsed into `dynamic`  -> "any"            (tolerant; any type ok)
 *
 * This is the A1 "lighter route": replay the old app's contract shapes against
 * the candidate backend (no Flutter/iOS build in CI). To re-pin after the live
 * app updates: move the tag, re-derive these schemas from the new models.
 */
abstract class BackwardsCompatTestCase extends TestCase
{
    /**
     * The pinned live App Store version these expectations were derived from.
     * Kept in sync with `LIVE_APP_TAG` in .github/workflows/backwards-compat.yml.
     */
    protected const LIVE_APP_TAG = 'app-live-v1.0.9';

    /**
     * Assert a decoded response satisfies a frozen live-app expectation schema.
     *
     * @param  mixed  $value  The decoded JSON (typically the full envelope).
     * @param  string  $schemaName  Schema base name under live-app-v1.0.9/.
     */
    protected function assertSatisfiesLiveApp(mixed $value, string $schemaName): void
    {
        $errors = ContractMatcher::validate($value, $this->loadLiveAppSchema($schemaName));

        $this->assertSame(
            [],
            $errors,
            'Candidate backend response would BREAK the live '.self::LIVE_APP_TAG
                ." app — it violates what that app parses:\n  - ".implode("\n  - ", $errors)
                ."\n\nThis is the 2026-05-23 incident class. If the shape change is "
                .'intentional, it can only ship AFTER a new app that tolerates it is '
                .'live (app-first), or with a backend that stays backward-compatible.'
        );
    }

    /**
     * Load and decode a frozen live-app expectation schema.
     *
     * @param  string  $name  Schema base name (without .json).
     * @return array<string,mixed> The decoded schema spec.
     */
    protected function loadLiveAppSchema(string $name): array
    {
        $path = __DIR__.'/live-app-v1.0.9/'.$name.'.json';
        $this->assertFileExists($path, "Missing live-app expectation schema: {$name}.json");

        /** @var array<string,mixed> $schema */
        $schema = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);

        return $schema;
    }
}
