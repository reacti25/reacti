<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

/**
 * Shared base test case for the backend suite.
 *
 * Every Feature and Unit test in `backend/tests` extends this class,
 * which in turn extends Laravel's framework `TestCase` to boot the
 * application for each test. It intentionally has no body yet —
 * suite-wide setup helpers and traits would be added here.
 */
abstract class TestCase extends BaseTestCase
{
    //
}
