<?php

namespace Tests\Smoke;

use GuzzleHttp\Client;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;
use Psr\Http\Message\ResponseInterface;

/**
 * HTTP smoke tests against a deployed backend.
 *
 * These tests reach over the network — they do NOT boot the Laravel
 * app or touch a local sqlite database. They use real test-user
 * accounts that must exist on the target backend.
 *
 * Configured by phpunit-smoke.xml; invoked via:
 *   php artisan test -c phpunit-smoke.xml
 * or .github/workflows/post-deploy-smoke.yml.
 *
 * Required env (typically GitHub Actions secrets):
 *   SMOKE_BASE_URL          e.g. https://reacti.io/api
 *   SMOKE_USER_A_EMAIL      A's login email
 *   SMOKE_USER_A_PASSWORD   A's login password
 *   SMOKE_USER_B_EMAIL      B's login email
 *   SMOKE_USER_B_PASSWORD   B's login password
 *
 * Optional (a test is skipped when missing):
 *   SMOKE_GROUP_ID          a group both A and B are members of
 *
 * Idempotency: each run sends one new chat from A to B and marks it
 * viewed. The friend / group / list endpoints are exercised
 * read-only. Designed to run repeatedly without corrupting state.
 */
class SmokeTest extends TestCase
{
    private static ?Client $http = null;

    /** @var array{id: int|string, token: string}|null */
    private static ?array $userA = null;

    /** @var array{id: int|string, token: string}|null */
    private static ?array $userB = null;

    protected function setUp(): void
    {
        parent::setUp();

        if (empty(getenv('SMOKE_BASE_URL'))) {
            $this->markTestSkipped('SMOKE_BASE_URL is not set — smoke suite skipped.');
        }

        if (! self::$http) {
            self::$http = new Client([
                'base_uri' => rtrim(getenv('SMOKE_BASE_URL'), '/').'/',
                // Don't have Guzzle throw on non-2xx — we want to
                // inspect the status ourselves.
                'http_errors' => false,
                'timeout' => 30,
                'connect_timeout' => 10,
                'headers' => [
                    'Accept' => 'application/json',
                ],
            ]);
        }
    }

    #[Test]
    public function health_check_endpoint_responds(): void
    {
        $res = self::$http->get('check');

        $this->assertSame(200, $res->getStatusCode(), 'GET /check should be 200');
        $this->assertNotEmpty((string) $res->getBody());
    }

    #[Test]
    public function user_a_can_log_in_and_receive_a_token(): void
    {
        $a = $this->ensureLoggedInAs('A');

        $this->assertNotEmpty($a['token']);
        $this->assertNotEmpty($a['id']);
    }

    #[Test]
    public function user_b_can_log_in_and_receive_a_token(): void
    {
        $b = $this->ensureLoggedInAs('B');

        $this->assertNotEmpty($b['token']);
        $this->assertNotEmpty($b['id']);
    }

    #[Test]
    public function user_a_can_fetch_their_profile(): void
    {
        $a = $this->ensureLoggedInAs('A');
        $res = self::$http->get('profile', ['headers' => $this->authHeader($a['token'])]);

        $this->assertSame(200, $res->getStatusCode());
        $body = $this->json($res);
        $this->assertTrue($body['success'] ?? false);
        $this->assertSame(getenv('SMOKE_USER_A_EMAIL'), $body['data']['email'] ?? null);
    }

    #[Test]
    public function combined_chat_list_endpoint_works(): void
    {
        $a = $this->ensureLoggedInAs('A');
        $res = self::$http->get('auth/chat/list', ['headers' => $this->authHeader($a['token'])]);

        $this->assertSame(200, $res->getStatusCode());
        $this->assertTrue($this->json($res)['success'] ?? false);
    }

    #[Test]
    public function friends_list_endpoint_works(): void
    {
        $a = $this->ensureLoggedInAs('A');
        $res = self::$http->get('friends/list', ['headers' => $this->authHeader($a['token'])]);

        $this->assertSame(200, $res->getStatusCode());
        $this->assertTrue($this->json($res)['success'] ?? false);
    }

    #[Test]
    public function group_list_endpoint_works(): void
    {
        $a = $this->ensureLoggedInAs('A');
        $res = self::$http->get('auth/group/list', ['headers' => $this->authHeader($a['token'])]);

        $this->assertSame(200, $res->getStatusCode());
        $this->assertTrue($this->json($res)['success'] ?? false);
    }

    #[Test]
    public function group_inbox_endpoint_works_when_a_group_id_is_provided(): void
    {
        $groupId = getenv('SMOKE_GROUP_ID');
        if (empty($groupId)) {
            $this->markTestSkipped('SMOKE_GROUP_ID not set — skipping group-inbox check.');
        }

        $a = $this->ensureLoggedInAs('A');
        $res = self::$http->get(
            "auth/group/{$groupId}/messages",
            ['headers' => $this->authHeader($a['token'])]
        );

        $this->assertSame(200, $res->getStatusCode());
        $this->assertTrue($this->json($res)['success'] ?? false);
    }

    #[Test]
    public function patent_flow_send_a_chat_then_mark_it_viewed(): void
    {
        $a = $this->ensureLoggedInAs('A');
        $b = $this->ensureLoggedInAs('B');

        // A sends a text message to B. Use a marker text so a human
        // inspecting prod can spot smoke runs.
        $sendRes = self::$http->post(
            "auth/chat/send/{$b['id']}",
            [
                'headers' => $this->authHeader($a['token']),
                'multipart' => [
                    ['name' => 'text', 'contents' => '[smoke-test] ping '.date('c')],
                    ['name' => 'message_type', 'contents' => 'normal'],
                ],
            ]
        );

        $this->assertSame(
            200,
            $sendRes->getStatusCode(),
            'A→B chat send should be 200; got: '.(string) $sendRes->getBody()
        );

        $sendBody = $this->json($sendRes);
        $this->assertTrue($sendBody['success'] ?? false);

        $messageId = $sendBody['data']['chat']['id']
            ?? $sendBody['data']['id']
            ?? null;
        $this->assertNotNull($messageId, 'Expected message id in send response.');

        // B marks the message viewed — the patent-flow mark-viewed call.
        $viewedRes = self::$http->post(
            "auth/chat/mark-viewed/{$messageId}",
            ['headers' => $this->authHeader($b['token'])]
        );

        $this->assertSame(
            200,
            $viewedRes->getStatusCode(),
            'mark-viewed should be 200; got: '.(string) $viewedRes->getBody()
        );
        $this->assertTrue($this->json($viewedRes)['success'] ?? false);
    }

    /**
     * Login (or reuse a cached token) for the given test user.
     *
     * @param  'A'|'B'  $which
     * @return array{id: int|string, token: string}
     */
    private function ensureLoggedInAs(string $which): array
    {
        if ($which === 'A' && self::$userA) {
            return self::$userA;
        }
        if ($which === 'B' && self::$userB) {
            return self::$userB;
        }

        $email = getenv("SMOKE_USER_{$which}_EMAIL");
        $password = getenv("SMOKE_USER_{$which}_PASSWORD");
        if (empty($email) || empty($password)) {
            $this->markTestSkipped("SMOKE_USER_{$which}_EMAIL / _PASSWORD not set.");
        }

        $res = self::$http->post('login', [
            'json' => [
                'email' => $email,
                'password' => $password,
            ],
        ]);

        $this->assertSame(
            200,
            $res->getStatusCode(),
            "login for user {$which} failed: ".(string) $res->getBody()
        );

        $body = $this->json($res);
        $token = $body['data']['token'] ?? null;
        $id = $body['data']['id'] ?? null;
        $this->assertNotEmpty($token, "no token in login response for {$which}");
        $this->assertNotEmpty($id, "no id in login response for {$which}");

        $record = ['id' => $id, 'token' => $token];
        if ($which === 'A') {
            self::$userA = $record;
        } else {
            self::$userB = $record;
        }

        return $record;
    }

    /** Bearer-token Authorization header. */
    private function authHeader(string $token): array
    {
        return ['Authorization' => "Bearer {$token}"];
    }

    /** Decode a JSON response body, asserting it parsed. */
    private function json(ResponseInterface $res): array
    {
        $decoded = json_decode((string) $res->getBody(), true);
        $this->assertIsArray($decoded, 'response body was not JSON: '.(string) $res->getBody());

        return $decoded;
    }
}
