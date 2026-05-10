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
        Event::fake([UserOnlineEvent::class]);

        $user = User::factory()->create([
            'otp_verified_at' => now(),
            'status'          => 'active',
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/logout');

        $resp->assertOk();

        Event::assertDispatched(
            UserOnlineEvent::class,
            fn (UserOnlineEvent $event): bool => (int) $event->userId === $user->id
                && $event->isOnline === false,
        );
        Event::assertDispatchedTimes(UserOnlineEvent::class, 1);
    }
}
