<?php

namespace Tests\Feature\Resources;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the response shape of the five paginated lists built by
 * `PaginatedCollection`: `data.<key>` is a list and `data.pagination` has
 * exactly the four fields the app's shared Pagination model reads.
 */
class PaginatedListShapeTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array<string, array{string, string}> url => [url, items key]
     */
    public static function lists(): array
    {
        return [
            'blocked users' => ['/api/block/list', 'blocked_users'],
            'reported users' => ['/api/report/list', 'reported_user'],
            'incoming requests' => ['/api/friends/requests', 'requests'],
            'sent requests' => ['/api/friends/requests/sent/list', 'requests'],
            'combined chats' => ['/api/auth/chat/list', 'chats'],
        ];
    }

    #[Test]
    #[DataProvider('lists')]
    public function list_has_its_items_key_and_the_pagination_block(string $url, string $key): void
    {
        $resp = $this->actingAs(User::factory()->create(), 'api')->getJson($url);

        $resp->assertOk()
            ->assertJsonPath("data.$key", [])
            ->assertJsonPath('data.pagination', [
                'total' => 0,
                'current_page' => 1,
                'last_page' => 1,
                'per_page' => $resp->json('data.pagination.per_page'),
            ]);
        $this->assertIsInt($resp->json('data.pagination.per_page'));
        $this->assertSame([$key, 'pagination'], array_keys($resp->json('data')));
    }
}
