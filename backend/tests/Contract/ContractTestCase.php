<?php

namespace Tests\Contract;

use Tests\Contract\Support\ContractMatcher;
use Tests\TestCase;

/**
 * Base class for API contract tests (Phase 3d).
 *
 * Contract tests lock the exact wire shape of the responses the live iOS
 * app parses, so a backend change that renames, removes, retypes, or
 * nulls a field is caught here — the class of bug that emptied every
 * private chat on 2026-05-23. Each committed schema under
 * tests/Contract/schemas/ is the source of truth for one endpoint; tests
 * exercise the real endpoint and assert the response matches.
 */
abstract class ContractTestCase extends TestCase
{
    /**
     * Assert that a decoded response value satisfies a committed contract.
     *
     * @param  mixed  $value  The decoded JSON (typically the full envelope).
     * @param  string  $schemaName  Schema file base name under schemas/.
     */
    protected function assertMatchesContract(mixed $value, string $schemaName): void
    {
        $errors = ContractMatcher::validate($value, $this->loadSchema($schemaName));

        $this->assertSame(
            [],
            $errors,
            "Response violated the '{$schemaName}' contract:\n  - ".implode("\n  - ", $errors)
                ."\n\nIf this change to the response shape is intentional, update "
                ."tests/Contract/schemas/{$schemaName}.json AND ship the matching iOS app change."
        );
    }

    /**
     * Load and decode a committed contract schema file.
     *
     * @param  string  $name  Schema file base name (without .json).
     * @return array<string,mixed> The decoded schema spec.
     */
    protected function loadSchema(string $name): array
    {
        $path = __DIR__."/schemas/{$name}.json";
        $this->assertFileExists($path, "Missing contract schema: {$name}.json");

        /** @var array<string,mixed> $schema */
        $schema = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);

        return $schema;
    }
}
