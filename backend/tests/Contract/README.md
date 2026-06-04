# Contract tests (Phase 3d)

This directory is the wall that catches **API-shape drift** — a backend change
that renames, removes, retypes, or nulls a field the live iOS app parses.
That class of bug is what emptied every private chat on 2026-05-23, and no
other test layer caught it because the response was still HTTP 200.

## How it works

1. Each endpoint the app depends on has a committed **schema** under
   [`schemas/`](schemas) — a small JSON file naming every required field
   and its type. `additive-safe`: extra fields are allowed (so adding a
   field doesn't break old apps), but a field that is **missing, renamed,
   retyped, or `null` when the schema says it can't be** fails the test.
2. A **PHPUnit test** under this directory builds a realistic scenario
   with factories, calls the real endpoint, and asserts the response
   matches its schema via `assertMatchesContract($response, 'schema-name')`.
3. Failures report the exact field path (e.g. `$.data.chat[0].is_blurred`)
   and remind you to update the schema and the matching iOS app code
   together if the change is intentional.

## Files

```
tests/Contract/
├── ContractTestCase.php          base class: loadSchema + assertMatchesContract
├── Support/ContractMatcher.php   the (unit-tested) matcher engine
├── schemas/*.json                one schema per endpoint (the contract)
└── *Test.php                     one PHPUnit class per endpoint group
```

The matcher itself has its own unit tests in
[`tests/Unit/Contract/ContractMatcherTest.php`](../Unit/Contract/ContractMatcherTest.php).

## Schema grammar (a small subset of JSON Schema)

Each leaf in a schema is a **type token**:

| Token | Meaning |
|---|---|
| `"integer"` / `"string"` / `"boolean"` / `"number"` | obvious |
| `"array"` / `"object"` / `"null"` / `"any"` | obvious |
| `"string\|null"` (etc.) | accepts either side |

A nested JSON object is itself a schema (recursive). For lists, use:

```json
{ "chats": { "__list__": { "id": "integer", "name": "string" } } }
```

Extra keys in the actual response are silently allowed (additive-safe).

## Adding a new endpoint contract

1. Write a one-off capture test that hits the endpoint with a realistic
   scenario and dumps the response JSON (e.g. via
   `file_put_contents(sys_get_temp_dir().'/dump.json', ...)`).
2. From the dumped JSON, hand-write
   `tests/Contract/schemas/<endpoint>.json` — list every required field
   and its type. For nullable fields use `"string|null"`. Keep object
   nesting flat-ish; lock the fields the app actually consumes.
3. Add the real test under `tests/Contract/<Group>ContractTest.php`:
   ```php
   $response = $this->actingAs($user, 'api')->getJson('/api/...');
   $response->assertOk();
   $this->assertMatchesContract($response->json(), 'endpoint-name');
   ```
4. Delete the capture test.

## Refreshing a contract (intentional shape change)

When you deliberately change a response shape:

1. Update the iOS app to handle the new shape.
2. Update the relevant `schemas/*.json` to match.
3. Both ship together. The contract test failing on staging *before*
   merge is the system working — don't bypass it.

## Running locally

```sh
cd backend
php artisan test --testsuite=Contract
```

## CI

`.github/workflows/contract-tests.yml` runs this suite on every PR to
`main` and `develop`. It is **observe-first** per the Phase 3 policy:
not yet a required status check on `protect-main`. Promote it after it
has been green on ~5 develop PRs.
