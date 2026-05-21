<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Socialite\Contracts\User as SocialiteUser;
use Laravel\Socialite\Facades\Socialite;
use Mockery;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Google social sign-in — `POST /api/social/signin/{provider}`.
 *
 * Before R10 this flow was dead twice over: the route pointed at a
 * `socialSignin` method that did not exist, and
 * `SocialAuthService::googleAuthenticate` wrote `name` /
 * `is_otp_verified` columns the `users` table does not have. These
 * tests pin the wired-up behaviour.
 *
 * Socialite is mocked — no real Google call is made.
 */
class SocialLoginTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Make `Socialite::driver('google')->stateless()->userFromToken()`
     * return a stubbed profile.
     */
    private function fakeGoogleUser(
        string $id,
        string $email,
        string $name,
        string $avatar = 'https://example.com/a.png'
    ): void {
        $socialUser = Mockery::mock(SocialiteUser::class);
        $socialUser->shouldReceive('getId')->andReturn($id);
        $socialUser->shouldReceive('getEmail')->andReturn($email);
        $socialUser->shouldReceive('getName')->andReturn($name);
        $socialUser->shouldReceive('getAvatar')->andReturn($avatar);

        $provider = Mockery::mock();
        $provider->shouldReceive('stateless')->andReturnSelf();
        $provider->shouldReceive('userFromToken')->andReturn($socialUser);

        Socialite::shouldReceive('driver')->with('google')->andReturn($provider);
    }

    #[Test]
    public function google_signin_creates_a_new_user_and_returns_a_token(): void
    {
        $this->fakeGoogleUser('google-uid-1', 'alice@gmail.com', 'Alice Walker');

        $resp = $this->postJson('/api/social/signin/google', ['token' => 'oauth-tok']);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertNotEmpty($resp->json('data.token'));

        $this->assertDatabaseHas('users', [
            'email' => 'alice@gmail.com',
            'first_name' => 'Alice',
            'last_name' => 'Walker',
            'google_id' => 'google-uid-1',
            'is_google_signin' => true,
        ]);

        // Social accounts skip the email-OTP step.
        $this->assertNotNull(User::where('email', 'alice@gmail.com')->first()->otp_verified_at);
    }

    #[Test]
    public function google_signin_links_to_an_existing_email_account(): void
    {
        $existing = User::factory()->create([
            'email' => 'bob@gmail.com',
            'first_name' => 'Bob',
        ]);

        $this->fakeGoogleUser('google-uid-2', 'bob@gmail.com', 'Bob Roberts');

        $resp = $this->postJson('/api/social/signin/google', ['token' => 'oauth-tok']);

        $resp->assertOk();
        $this->assertNotEmpty($resp->json('data.token'));

        // firstOrCreate matched the existing row — no duplicate created.
        $this->assertSame(1, User::where('email', 'bob@gmail.com')->count());
        $this->assertSame($existing->id, $resp->json('data.id'));
    }

    #[Test]
    public function social_signin_rejects_an_unsupported_provider(): void
    {
        $resp = $this->postJson('/api/social/signin/apple', ['token' => 'oauth-tok']);

        $resp->assertStatus(422);
        $resp->assertJsonPath('status', false);
    }

    #[Test]
    public function social_signin_404s_for_a_provider_outside_the_route_constraint(): void
    {
        // The route's whereIn allows only google|apple; anything else
        // does not match a route at all.
        $this->postJson('/api/social/signin/facebook', ['token' => 'x'])
            ->assertNotFound();
    }
}
