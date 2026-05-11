<?php

namespace Tests\Feature\Events;

use App\Events\UserOnlineEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Presence signals on the user-status channel.
 *
 * Clients in the chat list want to know when someone comes online or
 * goes offline so they can light up the green-dot indicator without
 * polling. These tests assert that:
 *
 *   - successful /api/login   → UserOnlineEvent(userId, true)
 *   - failed   /api/login     → no event (don't leak a false-positive)
 *   - /api/logout             → UserOnlineEvent(userId, false)
 */
class UserPresenceEventsTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Logging in with valid credentials must produce one UserOnlineEvent
     * with isOnline=true and the correct user id. Exactly one — a
     * regression that fired twice would double-trigger green-dot
     * toggles on listening clients.
     */
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

    /**
     * Wrong-password attempts must not broadcast anything. Otherwise a
     * brute-forcer could light up a victim's presence indicator
     * without ever logging in.
     */
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

    /**
     * Logout must broadcast isOnline=false so the green dot drops.
     *
     * The setup is the wordiest in this file — we have to log in
     * through the API to obtain a real JWT. `actingAs($user, 'api')`
     * does not parse a token, so `auth('api')->logout()` (which calls
     * JWT::invalidate()) errors out with no token in scope. Logging
     * in through the public endpoint gives the controller a real JWT
     * to invalidate.
     *
     * `Event::fake()` is delayed until after the login so the login's
     * broadcast doesn't pollute the assertion count.
     */
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
