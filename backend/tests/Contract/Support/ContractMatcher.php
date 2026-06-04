<?php

namespace Tests\Contract\Support;

/**
 * Validates a decoded JSON value against a lightweight, declarative shape
 * spec — the engine behind the API contract tests (Phase 3d).
 *
 * The spec is intentionally a small subset of JSON Schema, stored as plain
 * JSON files under tests/Contract/schemas/, so a contract is easy to read,
 * diff, and (later) reuse from the Flutter side. The matcher is
 * **additive-safe**: extra keys in the response are ignored, but a key that
 * the contract requires being missing, null when it must not be, or of the
 * wrong type is reported with its exact path (e.g. `$.data.chat[0].is_blurred`).
 * That is the precise failure mode of the 2026-05-23 incident.
 *
 * Spec grammar (each node is one of):
 *   - a type string: "integer" | "string" | "boolean" | "number" | "array"
 *     | "object" | "null" | "any", with "|" to allow alternatives
 *     (e.g. "string|null").
 *   - an object spec: a JSON object whose keys are required field names and
 *     whose values are nested specs.
 *   - a list spec: {"__list__": <spec>} — value must be a (possibly empty)
 *     array, and every element is validated against <spec>.
 */
class ContractMatcher
{
    /**
     * Validate a value against a spec, returning a list of human-readable
     * violation messages (empty when the value satisfies the contract).
     *
     * @param  mixed  $value  The decoded JSON value to check.
     * @param  array<string,mixed>|string  $spec  The shape spec node.
     * @param  string  $path  JSON-path-ish location used in error messages.
     * @return list<string> Violation messages; empty means valid.
     */
    public static function validate(mixed $value, array|string $spec, string $path = '$'): array
    {
        if (is_string($spec)) {
            return self::checkType($value, $spec, $path);
        }

        if (array_key_exists('__list__', $spec)) {
            return self::checkList($value, $spec['__list__'], $path);
        }

        return self::checkObject($value, $spec, $path);
    }

    /**
     * Check a scalar/leaf value against a (possibly alternated) type token.
     *
     * @param  mixed  $value  Value to test.
     * @param  string  $typeToken  e.g. "string", "integer", "string|null".
     * @param  string  $path  Location for the error message.
     * @return list<string> One violation, or none.
     */
    private static function checkType(mixed $value, string $typeToken, string $path): array
    {
        $allowed = explode('|', $typeToken);

        foreach ($allowed as $type) {
            if (self::matchesType($value, trim($type))) {
                return [];
            }
        }

        return ["{$path}: expected {$typeToken}, got ".self::describe($value)];
    }

    /**
     * Test whether a value matches a single primitive type name.
     *
     * @param  mixed  $value  Value to test.
     * @param  string  $type  One primitive type name.
     */
    private static function matchesType(mixed $value, string $type): bool
    {
        return match ($type) {
            'any' => true,
            'null' => $value === null,
            'string' => is_string($value),
            'integer' => is_int($value),
            'number' => is_int($value) || is_float($value),
            'boolean' => is_bool($value),
            'array' => is_array($value) && array_is_list($value),
            'object' => is_array($value) && ! array_is_list($value),
            default => false,
        };
    }

    /**
     * Validate that a value is a list and every element matches the item spec.
     *
     * @param  mixed  $value  Value expected to be a list.
     * @param  array<string,mixed>|string  $itemSpec  Spec each element must satisfy.
     * @param  string  $path  Location for error messages.
     * @return list<string> Accumulated violations.
     */
    private static function checkList(mixed $value, array|string $itemSpec, string $path): array
    {
        if (! is_array($value) || ! array_is_list($value)) {
            return ["{$path}: expected array, got ".self::describe($value)];
        }

        $errors = [];
        foreach ($value as $i => $item) {
            $errors = array_merge($errors, self::validate($item, $itemSpec, "{$path}[{$i}]"));
        }

        return $errors;
    }

    /**
     * Validate that a value is an object containing every required key, each
     * matching its sub-spec. Extra keys are allowed (additive-safe).
     *
     * @param  mixed  $value  Value expected to be an object (assoc array).
     * @param  array<string,mixed>  $spec  Map of required key => sub-spec.
     * @param  string  $path  Location for error messages.
     * @return list<string> Accumulated violations.
     */
    private static function checkObject(mixed $value, array $spec, string $path): array
    {
        if (! is_array($value) || array_is_list($value)) {
            return ["{$path}: expected object, got ".self::describe($value)];
        }

        $errors = [];
        foreach ($spec as $key => $subSpec) {
            $childPath = "{$path}.{$key}";
            if (! array_key_exists($key, $value)) {
                $errors[] = "{$childPath}: required key is missing";

                continue;
            }
            $errors = array_merge($errors, self::validate($value[$key], $subSpec, $childPath));
        }

        return $errors;
    }

    /**
     * Render a short, human-readable description of a value's actual type
     * for use in violation messages.
     *
     * @param  mixed  $value  The offending value.
     * @return string e.g. "null", "string", "list(3)", "object".
     */
    private static function describe(mixed $value): string
    {
        if ($value === null) {
            return 'null';
        }
        if (is_array($value)) {
            return array_is_list($value) ? 'list('.count($value).')' : 'object';
        }
        if (is_bool($value)) {
            return 'boolean';
        }

        return get_debug_type($value);
    }
}
