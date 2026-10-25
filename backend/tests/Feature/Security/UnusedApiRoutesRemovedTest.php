<?php

namespace Tests\Feature\Security;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * API routes no app version ever called (checked against every release tag
 * and the original delivery, 2026-10-25). `chat/search` matched on email and
 * returned other users' addresses; `firebase/test` pushed a fake "Payment
 * Failed" notification. Keep them gone.
 */
class UnusedApiRoutesRemovedTest extends TestCase
{
    use RefreshDatabase;

    /** @return array<string, array{string}> */
    public static function removedRoutes(): array
    {
        return [
            'chat search' => ['/api/auth/chat/search?keyword=a'],
            'chat room' => ['/api/auth/chat/room/1'],
            'seen single' => ['/api/auth/chat/seen/single/1'],
            'firebase test' => ['/api/firebase/test'],
        ];
    }

    #[Test]
    #[DataProvider('removedRoutes')]
    public function removed_route_is_not_found_even_when_signed_in(string $url): void
    {
        $this->actingAs(User::factory()->create(), 'api')->getJson($url)->assertNotFound();
    }
}
