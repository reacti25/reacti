<?php

namespace Tests\Unit;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * Guards that backend/.env.example stays safe to copy to production as-is.
 *
 * A prod `.env` derived from this template once risked leaking full Ignition
 * stack traces because the example shipped `APP_ENV=local`, `APP_DEBUG=true`,
 * and `LOG_LEVEL=debug`. This test pins the production-safe defaults so they
 * cannot regress, and checks the file carries no obvious committed secret.
 */
class EnvExampleProdSafeTest extends TestCase
{
    /**
     * Parse the committed .env.example into a key => value map, ignoring
     * blank lines and `#` comments.
     *
     * @return array<string, string>
     */
    private function envExample(): array
    {
        $path = __DIR__.'/../../.env.example';
        $this->assertFileExists($path, 'backend/.env.example is missing');

        $vars = [];
        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#') || ! str_contains($line, '=')) {
                continue;
            }
            [$key, $value] = explode('=', $line, 2);
            $vars[trim($key)] = trim($value);
        }

        return $vars;
    }

    /** The three values that caused the Ignition-leak risk must be prod-safe. */
    #[Test]
    public function it_ships_production_safe_defaults(): void
    {
        $env = $this->envExample();

        $this->assertSame('production', $env['APP_ENV'] ?? null, 'APP_ENV must default to production');
        $this->assertSame('false', $env['APP_DEBUG'] ?? null, 'APP_DEBUG must default to false (no Ignition leak)');
        $this->assertSame('error', $env['LOG_LEVEL'] ?? null, 'LOG_LEVEL must default to error, not debug');
    }

    /** Secret-bearing keys must ship empty in the example — never a real value. */
    #[Test]
    public function it_contains_no_committed_secret_values(): void
    {
        $env = $this->envExample();

        $secretKeys = [
            'APP_KEY', 'JWT_SECRET', 'APP_KEY_VALUE',
            'PUSHER_APP_SECRET', 'AWS_SECRET_ACCESS_KEY',
            'GOOGLE_CLIENT_SECRET', 'APPLE_CLIENT_SECRET', 'FACEBOOK_CLIENT_SECRET',
            'STRIPE_SECRET', 'STRIPE_WEBHOOK_SECRET',
        ];

        foreach ($secretKeys as $key) {
            if (array_key_exists($key, $env)) {
                $this->assertSame('', $env[$key], "{$key} must be empty in .env.example (no committed secret)");
            }
        }
    }
}
