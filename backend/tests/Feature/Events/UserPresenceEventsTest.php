<?php

namespace Tests\Feature\Events;

use App\Events\UserOnlineEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class UserPresenceEventsTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_successful_login_broadcasts_user_online_true(): void
    {
        Event::fake([UserOnlineEvent::class]);

        $user = User::factory()->create([
            'email'           => 'alice@example.com',
            'password'        => Hash::make('correct-horse'),
            'otp_verified_at' => now(),
            'status'          => 'active',
        ]);

        $resp = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'correct-horse',
        ]);

        $resp->assertOk();

        Event::assertDispatched(
            UserOnlineEvent::class,
            fn (UserOnlineEvent $event): bool => (int) $event->userId === $user->id
                && $event->isOnline === true,
        );
        Event::assertDispatchedTimes(UserOnlineEvent::class, 1);
    }

    #[Test]
    public function a_failed_login_does_not_broadcast_user_online(): void
    {
        Event::fake([UserOnlineEvent::class]);

        User::factory()->create([
            'email'           => 'alice@example.com',
            'password'        => Hash::make('correct-horse'),
            'otp_verified_at' => now(),
            'status'          => 'active',
        ]);

        $resp = $this->postJson('/api/login', [
            'email'    => 'alice@example.com',
            'password' => 'wrong-password-but-long-enough',
        ]);

        $resp->assertStatus(401);
        Event::assertNotDispatched(UserOnlineEvent::class);
    }

    #[Test]
    public function logout_broadcasts_user_online_false(): void
    {
        // Logout uses auth('api')->logout() which calls JWT::invalidate().
        // That requires a *real* parsed JWT — actingAs() does not parse one,
        // so we have to log in through the API to get a token, then pass
        // that token on the logout request.
        $user = User::factory()->create([
            'email'           => 'bob@example.com',
            'password'        => Hash::make('correct-horse'),
            'otp_verified_at' => now(),
            'status'          => 'active',
        ]);

        $loginResp = $this->postJson('/api/login', [
            'email'    => 'bob@example.com',
            'password' => 'correct-horse',
        ]);
        $loginResp->assertOk();
        $token = $loginResp->json('data.token');
        $this->assertNotEmpty($token, 'Login must return a JWT');

        // Fake AFTER login so the login broadcast doesn't pollute the count.
        Event::fake([UserOnlineEvent::class]);

        $logoutResp = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/logout');

        $logoutResp->assertOk();

        Event::assertDispatched(
            UserOnlineEvent::class,
            fn (UserOnlineEvent $event): bool => (int) $event->userId === $user->id
                && $event->isOnline === false,
        );
        Event::assertDispatchedTimes(UserOnlineEvent::class, 1);
    }
}
