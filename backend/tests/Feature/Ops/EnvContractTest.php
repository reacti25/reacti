<?php

namespace Tests\Feature\Ops;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * The AWS env contract (`.env.aws.example`, migration plan step 2.3) must
 * not drift from the code or from the compose stack that stands in for the
 * task definitions. Pure file checks, no application boot.
 */
class EnvContractTest extends TestCase
{
    private const CONTRACT = __DIR__.'/../../../.env.aws.example';

    private const COMPOSE = __DIR__.'/../../../../infra/compose.aws.yaml';

    /** Compose sets these for the S3 emulator; on AWS the task role replaces them. */
    private const COMPOSE_ONLY = [
        'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_ENDPOINT', 'AWS_USE_PATH_STYLE_ENDPOINT',
    ];

    /** Names that hold credentials; the contract must mark each one `# secret`. */
    private const SECRET_SUFFIX = '/(_KEY|_SECRET|PASSWORD|_TOKEN|_DSN|_CREDENTIALS|_SALT)$/';

    /** Names that are public even though the suffix says otherwise. */
    private const PUBLIC_DESPITE_SUFFIX = ['REVERB_APP_KEY'];

    #[Test]
    public function every_contract_variable_is_read_by_the_code(): void
    {
        $unread = array_diff(array_keys($this->contract()), $this->namesReadByCode());

        $this->assertSame([], array_values($unread), 'In .env.aws.example but no env() reads it: drop it or wire it.');
    }

    #[Test]
    public function the_compose_stack_sets_nothing_outside_the_contract(): void
    {
        $unknown = array_diff($this->composeNames(), array_keys($this->contract()), self::COMPOSE_ONLY);

        $this->assertSame([], array_values($unknown), 'infra/compose.aws.yaml sets a variable the contract does not list.');
    }

    #[Test]
    public function credentials_are_marked_secret_and_only_credentials_are(): void
    {
        foreach ($this->contract() as $name => $secret) {
            $looksSecret = preg_match(self::SECRET_SUFFIX, $name) === 1
                && ! in_array($name, self::PUBLIC_DESPITE_SUFFIX, true);

            $this->assertSame($looksSecret, $secret, "$name: `# secret` marker does not match the name.");
        }
    }

    #[Test]
    public function the_cloud_switches_are_present_and_static_keys_are_not(): void
    {
        $names = array_keys($this->contract());

        foreach (['MEDIA_DISK', 'TRUSTED_PROXIES', 'SERVED_BY', 'APP_MAINTENANCE_DRIVER', 'BROADCAST_CONNECTION',
            'MYSQL_ATTR_SSL_CA', 'QUEUE_CONNECTION', 'SESSION_DRIVER', 'CACHE_STORE'] as $required) {
            $this->assertContains($required, $names);
        }
        foreach (['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'REDIS_HOST', 'CACHE_DRIVER', 'BROADCAST_DRIVER'] as $banned) {
            $this->assertNotContains($banned, $names, "$banned has no place on AWS (task role / no Redis / dead Laravel 10 key).");
        }
    }

    /** @return array<string, bool> name => marked secret */
    private function contract(): array
    {
        $out = [];
        foreach (file(self::CONTRACT, FILE_IGNORE_NEW_LINES) as $line) {
            if (preg_match('/^([A-Z0-9_]+)=(.*)$/', $line, $m)) {
                $out[$m[1]] = str_contains($m[2], '# secret');
            }
        }
        $this->assertNotEmpty($out);

        return $out;
    }

    /** @return list<string> */
    private function namesReadByCode(): array
    {
        $root = realpath(__DIR__.'/../../..');
        $files = array_merge(
            glob("$root/config/*.php"),
            glob("$root/routes/*.php"),
            ["$root/bootstrap/app.php"],
            iterator_to_array($this->phpFilesUnder("$root/app"), false),
        );
        $names = [];
        foreach ($files as $file) {
            preg_match_all('/env\(\s*[\'"]([A-Z0-9_]+)[\'"]/', file_get_contents($file), $m);
            array_push($names, ...$m[1]);
        }

        return array_values(array_unique($names));
    }

    /** @return list<string> */
    private function composeNames(): array
    {
        $lines = file(self::COMPOSE, FILE_IGNORE_NEW_LINES);
        $names = [];
        $inBlock = false;
        foreach ($lines as $line) {
            if (str_starts_with($line, 'x-app-env:')) {
                $inBlock = true;

                continue;
            }
            if ($inBlock && ! str_starts_with($line, '  ')) {
                break;
            }
            if ($inBlock && preg_match('/^  ([A-Z0-9_]+):/', $line, $m)) {
                $names[] = $m[1];
            }
        }
        $this->assertNotEmpty($names, 'x-app-env block not found in compose.aws.yaml');

        return $names;
    }

    /** @return \Generator<string> */
    private function phpFilesUnder(string $dir): \Generator
    {
        $it = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($dir, \FilesystemIterator::SKIP_DOTS));
        foreach ($it as $file) {
            if ($file->getExtension() === 'php') {
                yield $file->getPathname();
            }
        }
    }
}
