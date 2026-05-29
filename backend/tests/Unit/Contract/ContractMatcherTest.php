<?php

namespace Tests\Unit\Contract;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;
use Tests\Contract\Support\ContractMatcher;

/**
 * Unit tests for ContractMatcher — the engine that powers the API
 * contract tests. Verifies type checking, required-key detection,
 * nullable handling, additive-safety, list validation, and that
 * violations report the exact failing path.
 */
class ContractMatcherTest extends TestCase
{
    /** A fully-matching object yields no violations. */
    #[Test]
    public function valid_object_passes(): void
    {
        $errors = ContractMatcher::validate(
            ['id' => 1, 'name' => 'x', 'active' => true],
            ['id' => 'integer', 'name' => 'string', 'active' => 'boolean'],
        );

        $this->assertSame([], $errors);
    }

    /** A missing required key is reported with its path. */
    #[Test]
    public function missing_key_is_reported(): void
    {
        $errors = ContractMatcher::validate(['id' => 1], ['id' => 'integer', 'token' => 'string']);

        $this->assertCount(1, $errors);
        $this->assertStringContainsString('$.token', $errors[0]);
        $this->assertStringContainsString('missing', $errors[0]);
    }

    /** A wrong scalar type is reported. */
    #[Test]
    public function wrong_type_is_reported(): void
    {
        $errors = ContractMatcher::validate(['id' => 'oops'], ['id' => 'integer']);

        $this->assertCount(1, $errors);
        $this->assertStringContainsString('$.id', $errors[0]);
        $this->assertStringContainsString('expected integer', $errors[0]);
    }

    /** A nullable type accepts both null and the base type. */
    #[Test]
    public function nullable_type_accepts_null(): void
    {
        $this->assertSame([], ContractMatcher::validate(['x' => null], ['x' => 'string|null']));
        $this->assertSame([], ContractMatcher::validate(['x' => 'hi'], ['x' => 'string|null']));
    }

    /** Extra keys not in the spec are allowed (additive-safe). */
    #[Test]
    public function extra_keys_are_allowed(): void
    {
        $errors = ContractMatcher::validate(
            ['id' => 1, 'new_field' => 'whatever'],
            ['id' => 'integer'],
        );

        $this->assertSame([], $errors);
    }

    /** List specs validate every element and report the offending index. */
    #[Test]
    public function list_validates_each_item(): void
    {
        $spec = ['items' => ['__list__' => ['id' => 'integer']]];

        $this->assertSame([], ContractMatcher::validate(['items' => [['id' => 1], ['id' => 2]]], $spec));

        $errors = ContractMatcher::validate(['items' => [['id' => 1], ['id' => 'bad']]], $spec);
        $this->assertCount(1, $errors);
        $this->assertStringContainsString('$.items[1].id', $errors[0]);
    }

    /** An object where a list is expected (and vice-versa) is reported. */
    #[Test]
    public function shape_mismatch_is_reported(): void
    {
        $listErrors = ContractMatcher::validate(['items' => 'notalist'], ['items' => ['__list__' => 'integer']]);
        $this->assertCount(1, $listErrors);
        $this->assertStringContainsString('expected array', $listErrors[0]);

        $objErrors = ContractMatcher::validate(['obj' => [1, 2, 3]], ['obj' => ['id' => 'integer']]);
        $this->assertCount(1, $objErrors);
        $this->assertStringContainsString('expected object', $objErrors[0]);
    }

    /** Violations deep in a nested structure carry the full path. */
    #[Test]
    public function nested_path_is_reported(): void
    {
        $errors = ContractMatcher::validate(
            ['data' => ['user' => ['id' => 'bad']]],
            ['data' => ['user' => ['id' => 'integer']]],
        );

        $this->assertCount(1, $errors);
        $this->assertStringContainsString('$.data.user.id', $errors[0]);
    }
}
